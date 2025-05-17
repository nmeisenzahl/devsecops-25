package utils

import (
	"log"
)

// LogDebug logs a debug message
func LogDebug(message string) {
	log.Printf("Debug: %s", message)
}

// LogError logs an error message
func LogError(err error) {
	if err != nil {
		log.Printf("Error: %v", err)
	}
}

// LogInfo logs an informational message
func LogInfo(message string) {
	log.Printf("Info: %s", message)
}
