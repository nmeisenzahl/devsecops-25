package main

import (
	"log"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/nmeisenzahl/devsecops-25/configs"
	"github.com/nmeisenzahl/devsecops-25/internal/db"
	"github.com/nmeisenzahl/devsecops-25/internal/handlers"
)

func main() {
	// Load configuration
	config, err := configs.LoadConfig()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Initialize database connection
	dbConn, err := db.NewConnection(config)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	// Initialize Gin router
	router := gin.Default()

	// Define routes for CRUD operations
	userHandler := handlers.NewUserHandler(dbConn)
	router.POST("/user", userHandler.CreateUser)
	router.GET("/user/:id", userHandler.GetUser)
	router.PUT("/user/:id", userHandler.UpdateUser)
	router.DELETE("/user/:id", userHandler.DeleteUser)

	// Start the server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	router.Run(":" + port)
}
