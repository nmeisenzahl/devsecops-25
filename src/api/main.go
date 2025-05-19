package main

import (
	"context"
	"log"
	"net/http"
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
	dbConn, err := db.NewConnection(context.Background(), config)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	// Seed the database (create tables if needed)
	if err := dbConn.Seed(); err != nil {
		log.Fatalf("Failed to seed database: %v", err)
	}

	// Initialize Gin router
	router := gin.Default()

	// Safe, parameterized endpoints (v1)
	userHandler := handlers.NewUserHandler(dbConn)
	v1 := router.Group("/v1")
	v1.POST("/user", userHandler.CreateUser)
	v1.GET("/user/:id", userHandler.GetUser)
	v1.PUT("/user/:id", userHandler.UpdateUser)
	v1.DELETE("/user/:id", userHandler.DeleteUser)

	// Add health check endpoint under v1
	v1.GET("/healthz", func(c *gin.Context) {
		c.Status(http.StatusOK)
	})
	// Vulnerable SQL injection demo endpoints (v2)
	v2 := router.Group("/v2")
	v2.GET("/user/:id", userHandler.GetUserV2)

	// Start the server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	router.Run(":" + port)
}
