package db

import (
	"database/sql"
	"fmt"
)

func SeedDatabase(db *sql.DB) error {
	// Check if the users table exists
	query := `
	IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'users')
	BEGIN
		CREATE TABLE users (
			id INT PRIMARY KEY IDENTITY(1,1),
			name NVARCHAR(100) NOT NULL,
			email NVARCHAR(100) NOT NULL
		)
	END`
	_, err := db.Exec(query)
	if err != nil {
		return fmt.Errorf("failed to seed database: %v", err)
	}

	return nil
}
