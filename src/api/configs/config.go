package configs

import (
	"fmt"
	"log"

	"github.com/spf13/viper"
)

type Config struct {
	DBServer   string
	DBDatabase string
}

func LoadConfig() (*Config, error) {
	viper.SetConfigFile(".env")

	viper.AutomaticEnv()

	if err := viper.ReadInConfig(); err != nil {
		log.Printf("Error reading config file, %s", err)
	}

	config := &Config{
		DBServer:   viper.GetString("DB_SERVER"),
		DBDatabase: viper.GetString("DB_DATABASE"),
	}

	if config.DBServer == "" || config.DBDatabase == "" {
		return nil, fmt.Errorf("missing required environment variables")
	}

	return config, nil
}
