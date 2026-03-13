package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"

	_ "github.com/lib/pq"
	"golang.org/x/crypto/bcrypt"

	"okey101/services/api_go/internal/game101"
	"okey101/services/api_go/internal/handlers"
)

type RegisterRequest struct {
	Username    string `json:"username"`
	Email       string `json:"email"`
	Password    string `json:"password"`
	DisplayName string `json:"display_name"`
}

type LoginRequest struct {
	Identifier string `json:"identifier"`
	Email      string `json:"email"`
	Username   string `json:"username"`
	Password   string `json:"password"`
}

type LoginResponse struct {
	ID          int64                  `json:"id"`
	UserID      int64                  `json:"user_id"`
	Username    string                 `json:"username"`
	Email       string                 `json:"email"`
	DisplayName string                 `json:"display_name"`
	User        map[string]interface{} `json:"user"`
}

func main() {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://postgres:postgres123@localhost:5432/okey101?sslmode=disable"
	}

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		log.Fatal(err)
	}

	tableHandler := handlers.NewTableHandler(db)
	gameService := game101.NewService(db)
	gameHandler := handlers.NewGameHandler(gameService)

	mux := http.NewServeMux()

	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]interface{}{
			"status": "ok",
		})
	})

	mux.HandleFunc("/auth/register", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var req RegisterRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid body", http.StatusBadRequest)
			return
		}

		username := strings.TrimSpace(req.Username)
		email := strings.TrimSpace(strings.ToLower(req.Email))
		password := strings.TrimSpace(req.Password)
		displayName := strings.TrimSpace(req.DisplayName)

		if username == "" || email == "" || password == "" {
			http.Error(w, "username, email and password required", http.StatusBadRequest)
			return
		}

		if displayName == "" {
			displayName = username
		}

		var exists int
		err := db.QueryRow(`
            SELECT COUNT(1)
            FROM users
            WHERE email = $1 OR username = $2
        `, email, username).Scan(&exists)
		if err != nil {
			http.Error(w, "failed to check existing user", http.StatusInternalServerError)
			return
		}

		if exists > 0 {
			http.Error(w, "user already exists", http.StatusConflict)
			return
		}

		passwordHash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
		if err != nil {
			http.Error(w, "failed to hash password", http.StatusInternalServerError)
			return
		}

		var id int64
		err = db.QueryRow(`
            INSERT INTO users (username, email, display_name, password_hash)
            VALUES ($1, $2, $3, $4)
            RETURNING id
        `, username, email, displayName, string(passwordHash)).Scan(&id)
		if err != nil {
			http.Error(w, "failed to create user", http.StatusInternalServerError)
			return
		}

		writeJSON(w, http.StatusCreated, map[string]interface{}{
			"id":           id,
			"user_id":      id,
			"username":     username,
			"email":        email,
			"display_name": displayName,
			"user": map[string]interface{}{
				"id":           id,
				"user_id":      id,
				"username":     username,
				"email":        email,
				"display_name": displayName,
			},
		})
	})

	mux.HandleFunc("/auth/login", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var req LoginRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid body", http.StatusBadRequest)
			return
		}

		identifier := strings.TrimSpace(req.Identifier)
		if identifier == "" {
			if strings.TrimSpace(req.Email) != "" {
				identifier = strings.TrimSpace(req.Email)
			} else {
				identifier = strings.TrimSpace(req.Username)
			}
		}

		if identifier == "" || strings.TrimSpace(req.Password) == "" {
			http.Error(w, "identifier and password required", http.StatusBadRequest)
			return
		}

		var id int64
		var username string
		var email string
		var displayName string
		var passwordHash string

		err := db.QueryRow(`
            SELECT id, username, email, display_name, password_hash
            FROM users
            WHERE email = $1 OR username = $1
            LIMIT 1
        `, identifier).Scan(
			&id,
			&username,
			&email,
			&displayName,
			&passwordHash,
		)
		if err == sql.ErrNoRows {
			http.Error(w, "invalid credentials", http.StatusUnauthorized)
			return
		}
		if err != nil {
			http.Error(w, "failed to query user", http.StatusInternalServerError)
			return
		}

		if err := bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(req.Password)); err != nil {
			http.Error(w, "invalid credentials", http.StatusUnauthorized)
			return
		}

		resp := LoginResponse{
			ID:          id,
			UserID:      id,
			Username:    username,
			Email:       email,
			DisplayName: displayName,
			User: map[string]interface{}{
				"id":           id,
				"user_id":      id,
				"username":     username,
				"email":        email,
				"display_name": displayName,
			},
		}

		writeJSON(w, http.StatusOK, resp)
	})

	mux.HandleFunc("/tables", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/tables" {
			http.NotFound(w, r)
			return
		}

		switch r.Method {
		case http.MethodGet:
			tableHandler.ListTables(w, r)
		case http.MethodPost:
			tableHandler.CreateTable(w, r)
		default:
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})

	mux.HandleFunc("/tables/", func(w http.ResponseWriter, r *http.Request) {
		switch {
		case strings.HasSuffix(r.URL.Path, "/join"):
			tableHandler.JoinTable(w, r)
			return
		case strings.HasSuffix(r.URL.Path, "/leave"):
			tableHandler.LeaveTable(w, r)
			return
		default:
			if r.Method != http.MethodGet {
				http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
				return
			}
			tableHandler.GetTable(w, r)
			return
		}
	})

	mux.HandleFunc("/games/start", func(w http.ResponseWriter, r *http.Request) {
		gameHandler.StartGame(w, r)
	})

	mux.HandleFunc("/games/", func(w http.ResponseWriter, r *http.Request) {
		switch {
		case strings.HasSuffix(r.URL.Path, "/draw"):
			gameHandler.DrawTile(w, r)
			return
		case strings.HasSuffix(r.URL.Path, "/discard"):
			gameHandler.DiscardTile(w, r)
			return
		case strings.HasSuffix(r.URL.Path, "/open"):
			gameHandler.OpenHand(w, r)
			return
		case strings.HasSuffix(r.URL.Path, "/bot-turns"):
			gameHandler.RunBotTurns(w, r)
			return
		default:
			gameHandler.GetGame(w, r)
			return
		}
	})

	log.Println("api listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", mux))
}
