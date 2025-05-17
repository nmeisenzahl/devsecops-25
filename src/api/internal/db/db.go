package db

import (
	"context"
	"database/sql"
	"fmt"
	"os"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore/policy"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	_ "github.com/denisenkom/go-mssqldb"

	"github.com/nmeisenzahl/devsecops-25/internal/models"
)

type DB struct {
	conn *sql.DB
}

func NewConnection(config *Config) (*DB, error) {
	// Use environment variables to configure connection properties
	server := os.Getenv("DB_SERVER")
	database := os.Getenv("DB_DATABASE")

	// Use Azure's DefaultAzureCredential for authentication
	cred, err := azidentity.NewDefaultAzureCredential(nil)
	if err != nil {
		return nil, fmt.Errorf("failed to obtain Azure credential: %v", err)
	}

	token, err := cred.GetToken(context.TODO(), policy.TokenRequestOptions{
		Scopes: []string{"https://database.windows.net/.default"},
	})
	if err != nil {
		return nil, fmt.Errorf("failed to obtain token: %v", err)
	}

	connString := fmt.Sprintf("server=%s;database=%s;access token=%s", server, database, token.Token)
	conn, err := sql.Open("sqlserver", connString)
	if err != nil {
		return nil, fmt.Errorf("failed to open database connection: %v", err)
	}

	return &DB{conn: conn}, nil
}

func (db *DB) CreateUser(user *models.User) error {
	query := "INSERT INTO users (name, email) VALUES (@name, @mail)"
	_, err := db.conn.Exec(query, sql.Named("name", user.Name), sql.Named("email", user.Email))
	return err
}

func (db *DB) GetUser(id int) (*models.User, error) {
	query := "SELECT id, name, email FROM users WHERE id = @id"
	row := db.conn.QueryRow(query, sql.Named("id", id))

	var user models.User
	err := row.Scan(&user.ID, &user.Name, &user.Email)
	if err != nil {
		return nil, err
	}

	return &user, nil
}

func (db *DB) UpdateUser(user *models.User) error {
	query := "UPDATE users SET name = @name, email = @mail WHERE id = @id"
	_, err := db.conn.Exec(query, sql.Named("name", user.Name), sql.Named("email", user.Email), sql.Named("id", user.ID))
	return err
}

func (db *DB) DeleteUser(id int) error {
	query := "DELETE FROM users WHERE id = @id"
	_, err := db.conn.Exec(query, sql.Named("id", id))
	return err
}
