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

    "okey101/services/api_go/internal/handlers"
)

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

    mux := http.NewServeMux()

    mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        writeJSON(w, http.StatusOK, map[string]interface{}{
            "status": "ok",
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
            http.Error(w, err.Error(), http.StatusInternalServerError)
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

        if r.Method != http.MethodGet {
            http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
            return
        }

        tableHandler.ListTables(w, r)
    })

    mux.HandleFunc("/tables/", func(w http.ResponseWriter, r *http.Request) {
        if strings.HasSuffix(r.URL.Path, "/join") {
            tableHandler.JoinTable(w, r)
            return
        }

        if r.Method != http.MethodGet {
            http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
            return
        }

        tableHandler.GetTable(w, r)
    })

    log.Println("api listening on :8080")
    log.Fatal(http.ListenAndServe(":8080", mux))
}

func writeJSON(w http.ResponseWriter, status int, payload interface{}) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    _ = json.NewEncoder(w).Encode(payload)
}
