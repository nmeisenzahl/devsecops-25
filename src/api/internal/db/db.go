package db

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore/policy"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	mssql "github.com/denisenkom/go-mssqldb"

	"github.com/nmeisenzahl/devsecops-25/configs"
	"github.com/nmeisenzahl/devsecops-25/internal/models"
	"github.com/nmeisenzahl/devsecops-25/internal/utils"
)

type DB struct {
	conn *sql.DB
}

// NewConnection creates a new DB using the provided context and config
func NewConnection(ctx context.Context, cfg *configs.Config) (*DB, error) {
	utils.LogInfo("DB: starting new connection")
	// Use values from external configurations to configure connection properties
	server := cfg.DBServer
	database := cfg.DBDatabase

	// Use Azure's DefaultAzureCredential for authentication
	cred, err := azidentity.NewDefaultAzureCredential(nil)
	if err != nil {
		utils.LogError(err)
		return nil, fmt.Errorf("failed to obtain Azure credential: %v", err)
	}

	// Build base connection string with Active Directory token authentication enforced
	baseConnStr := fmt.Sprintf("server=%s;database=%s;encrypt=true;authentication=ActiveDirectoryAccessToken", server, database)
	// Token provider using DefaultAzureCredential
	tokenProvider := func() (string, error) {
		tok, err := cred.GetToken(ctx, policy.TokenRequestOptions{
			Scopes: []string{"https://database.windows.net/.default"},
		})
		if err != nil {
			utils.LogError(err)
			return "", fmt.Errorf("failed to refresh Azure token: %v", err)
		}
		return tok.Token, nil
	}
	connector, err := mssql.NewAccessTokenConnector(baseConnStr, tokenProvider)
	if err != nil {
		utils.LogError(err)
		return nil, fmt.Errorf("failed to create token connector: %v", err)
	}
	conn := sql.OpenDB(connector)

	// Verify database connectivity
	if err := conn.PingContext(ctx); err != nil {
		utils.LogError(err)
		return nil, fmt.Errorf("failed to ping database: %v", err)
	}
	utils.LogInfo("DB: connection established and ping successful")

	return &DB{conn: conn}, nil
}

func (db *DB) CreateUser(user *models.User) error {
	utils.LogInfo(fmt.Sprintf("DB: CreateUser start name=%s email=%s", user.Name, user.Email))
	// Use OUTPUT clause to retrieve the new user ID for SQL Server
	query := "INSERT INTO users (name, email) OUTPUT inserted.id VALUES (@name, @email)"
	var id int
	err := db.conn.QueryRow(query, sql.Named("name", user.Name), sql.Named("email", user.Email)).Scan(&id)
	if err != nil {
		utils.LogError(err)
		return err
	}
	user.ID = id
	utils.LogInfo(fmt.Sprintf("DB: CreateUser completed successfully, id=%d", user.ID))
	return nil
}

func (db *DB) GetUser(id int) (*models.User, error) {
	utils.LogInfo(fmt.Sprintf("DB: GetUser start id=%d", id))
	query := "SELECT id, name, email FROM users WHERE id = @id"
	row := db.conn.QueryRow(query, sql.Named("id", id))

	var user models.User
	err := row.Scan(&user.ID, &user.Name, &user.Email)
	if err != nil {
		utils.LogError(err)
		return nil, err
	}

	utils.LogInfo(fmt.Sprintf("DB: GetUser completed result=%+v", user))
	return &user, nil
}

func (db *DB) UpdateUser(user *models.User) error {
	utils.LogInfo(fmt.Sprintf("DB: UpdateUser start id=%d name=%s email=%s", user.ID, user.Name, user.Email))
	query := "UPDATE users SET name = @name, email = @email WHERE id = @id"
	_, err := db.conn.Exec(query, sql.Named("name", user.Name), sql.Named("email", user.Email), sql.Named("id", user.ID))
	if err != nil {
		utils.LogError(err)
		return err
	}
	utils.LogInfo("DB: UpdateUser completed successfully")
	return nil
}

func (db *DB) DeleteUser(id int) error {
	utils.LogInfo(fmt.Sprintf("DB: DeleteUser start id=%d", id))
	query := "DELETE FROM users WHERE id = @id"
	_, err := db.conn.Exec(query, sql.Named("id", id))
	if err != nil {
		utils.LogError(err)
		return err
	}
	utils.LogInfo("DB: DeleteUser completed successfully")
	return nil
}

// Vulnerable method susceptible to SQL injection demonstration
func (db *DB) GetUserV2(idParam string) ([]models.User, error) {
	utils.LogInfo(fmt.Sprintf("DB: GetUserV2 start idParam=%s", idParam))
	// WARNING: directly concatenating user input into SQL query
	query := fmt.Sprintf("SELECT id, name, email FROM users WHERE id = %s", idParam)
	rows, err := db.conn.Query(query)
	if err != nil {
		utils.LogError(err)
		return nil, err
	}
	defer rows.Close()

	var users []models.User
	for rows.Next() {
		var u models.User
		if err := rows.Scan(&u.ID, &u.Name, &u.Email); err != nil {
			utils.LogError(err)
			return nil, err
		}
		users = append(users, u)
	}
	return users, nil
}

// Seed runs the database seed logic (e.g., creating tables) using the SeedDatabase helper.
func (d *DB) Seed() error {
	utils.LogInfo("DB: seeding database")
	err := SeedDatabase(d.conn)
	if err != nil {
		utils.LogError(err)
		return err
	}
	utils.LogInfo("DB: database seeding completed successfully")
	return nil
}
