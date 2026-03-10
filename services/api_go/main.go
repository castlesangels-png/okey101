package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/joho/godotenv"
	"golang.org/x/crypto/bcrypt"
)

type RegisterRequest struct {
	Username    string `json:"username"`
	Email       string `json:"email"`
	Password    string `json:"password"`
	DisplayName string `json:"display_name"`
}

func main() {
	_ = godotenv.Load()

	appPort := getEnv("APP_PORT", "8080")
	dbHost := getEnv("POSTGRES_HOST", "localhost")
	dbPort := getEnv("POSTGRES_PORT", "5432")
	dbName := getEnv("POSTGRES_DB", "okey101")
	dbUser := getEnv("POSTGRES_USER", "postgres")
	dbPassword := getEnv("POSTGRES_PASSWORD", "postgres123")

	connString := fmt.Sprintf(
		"host=%s port=%s dbname=%s user=%s password=%s sslmode=disable",
		dbHost, dbPort, dbName, dbUser, dbPassword,
	)

	router := gin.Default()

	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"service": "api_go",
			"time":    time.Now().Format(time.RFC3339),
		})
	})

	router.GET("/health/db", func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		conn, err := pgx.Connect(ctx, connString)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"status":  "error",
				"message": "database connection failed",
				"error":   err.Error(),
			})
			return
		}
		defer conn.Close(ctx)

		var now time.Time
		err = conn.QueryRow(ctx, "SELECT NOW()").Scan(&now)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"status":  "error",
				"message": "database query failed",
				"error":   err.Error(),
			})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"status":   "ok",
			"service":  "api_go",
			"database": "connected",
			"db_time":  now.Format(time.RFC3339),
		})
	})

	router.POST("/auth/register", func(c *gin.Context) {
		var req RegisterRequest

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"status":  "error",
				"message": "invalid request body",
				"error":   err.Error(),
			})
			return
		}

		req.Username = strings.TrimSpace(strings.ToLower(req.Username))
		req.Email = strings.TrimSpace(strings.ToLower(req.Email))
		req.DisplayName = strings.TrimSpace(req.DisplayName)

		if req.Username == "" || req.Email == "" || req.Password == "" || req.DisplayName == "" {
			c.JSON(http.StatusBadRequest, gin.H{
				"status":  "error",
				"message": "username, email, password and display_name are required",
			})
			return
		}

		if len(req.Password) < 6 {
			c.JSON(http.StatusBadRequest, gin.H{
				"status":  "error",
				"message": "password must be at least 6 characters",
			})
			return
		}

		passwordHash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"status":  "error",
				"message": "failed to hash password",
				"error":   err.Error(),
			})
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		conn, err := pgx.Connect(ctx, connString)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"status":  "error",
				"message": "database connection failed",
				"error":   err.Error(),
			})
			return
		}
		defer conn.Close(ctx)

		tx, err := conn.Begin(ctx)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"status":  "error",
				"message": "failed to begin transaction",
				"error":   err.Error(),
			})
			return
		}
		defer tx.Rollback(ctx)

		var userID int64
		err = tx.QueryRow(ctx, `
            INSERT INTO users (username, email, password_hash, display_name)
            VALUES ($1, $2, $3, $4)
            RETURNING id
        `, req.Username, req.Email, string(passwordHash), req.DisplayName).Scan(&userID)

		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"status":  "error",
				"message": "failed to create user",
				"error":   err.Error(),
			})
			return
		}

		startingBalance := int64(10000)

		_, err = tx.Exec(ctx, `
            INSERT INTO chip_wallets (user_id, balance)
            VALUES ($1, $2)
        `, userID, startingBalance)

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"status":  "error",
				"message": "failed to create wallet",
				"error":   err.Error(),
			})
			return
		}

		_, err = tx.Exec(ctx, `
            INSERT INTO chip_transactions (user_id, tx_type, amount, balance_after, description)
            VALUES ($1, $2, $3, $4, $5)
        `, userID, "welcome_bonus", startingBalance, startingBalance, "Initial welcome chips")

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"status":  "error",
				"message": "failed to create initial transaction",
				"error":   err.Error(),
			})
			return
		}

		if err := tx.Commit(ctx); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"status":  "error",
				"message": "failed to commit transaction",
				"error":   err.Error(),
			})
			return
		}

		c.JSON(http.StatusCreated, gin.H{
			"status":  "ok",
			"message": "user registered successfully",
			"user": gin.H{
				"id":           userID,
				"username":     req.Username,
				"email":        req.Email,
				"display_name": req.DisplayName,
				"balance":      startingBalance,
			},
		})
	})

	router.Run(":" + appPort)
}

func getEnv(key, fallback string) string {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	return value
}
