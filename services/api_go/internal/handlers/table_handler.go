package handlers

import (
    "database/sql"
    "encoding/json"
    "net/http"
    "strconv"
    "strings"
)

type TableHandler struct {
    DB *sql.DB
}

type TablePlayerDTO struct {
    UserID      int    `json:"user_id"`
    Username    string `json:"username"`
    DisplayName string `json:"display_name"`
    SeatNo      int    `json:"seat_no"`
}

type TableDTO struct {
    ID             int              `json:"id"`
    Name           string           `json:"name"`
    GameType       string           `json:"game_type"`
    MaxPlayers     int              `json:"max_players"`
    CurrentPlayers int              `json:"current_players"`
    MinBuyIn       int              `json:"min_buy_in"`
    Status         string           `json:"status"`
    Players        []TablePlayerDTO `json:"players,omitempty"`
}

func NewTableHandler(db *sql.DB) *TableHandler {
    return &TableHandler{DB: db}
}

func (h *TableHandler) ListTables(w http.ResponseWriter, r *http.Request) {
    rows, err := h.DB.Query(`
        SELECT id, name, game_type, max_players, current_players, stake_amount, status
        FROM game_tables
        ORDER BY id ASC
    `)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    defer rows.Close()

    tables := make([]TableDTO, 0)

    for rows.Next() {
        var t TableDTO
        if err := rows.Scan(
            &t.ID,
            &t.Name,
            &t.GameType,
            &t.MaxPlayers,
            &t.CurrentPlayers,
            &t.MinBuyIn,
            &t.Status,
        ); err != nil {
            http.Error(w, err.Error(), http.StatusInternalServerError)
            return
        }
        tables = append(tables, t)
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(tables)
}

func (h *TableHandler) GetTable(w http.ResponseWriter, r *http.Request) {
    id, ok := extractTableID(r.URL.Path)
    if !ok {
        http.Error(w, "invalid table id", http.StatusBadRequest)
        return
    }

    var t TableDTO
    err := h.DB.QueryRow(`
        SELECT id, name, game_type, max_players, current_players, stake_amount, status
        FROM game_tables
        WHERE id = $1
    `, id).Scan(
        &t.ID,
        &t.Name,
        &t.GameType,
        &t.MaxPlayers,
        &t.CurrentPlayers,
        &t.MinBuyIn,
        &t.Status,
    )

    if err == sql.ErrNoRows {
        http.Error(w, "table not found", http.StatusNotFound)
        return
    }
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    playerRows, err := h.DB.Query(`
        SELECT tp.user_id, u.username, u.display_name, tp.seat_no
        FROM table_players tp
        INNER JOIN users u ON u.id = tp.user_id
        WHERE tp.table_id = $1
        ORDER BY tp.seat_no ASC
    `, id)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    defer playerRows.Close()

    players := make([]TablePlayerDTO, 0)
    for playerRows.Next() {
        var p TablePlayerDTO
        if err := playerRows.Scan(
            &p.UserID,
            &p.Username,
            &p.DisplayName,
            &p.SeatNo,
        ); err != nil {
            http.Error(w, err.Error(), http.StatusInternalServerError)
            return
        }
        players = append(players, p)
    }

    t.Players = players

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(t)
}

type JoinTableRequest struct {
    UserID int `json:"user_id"`
}

type JoinTableResponse struct {
    Success bool   `json:"success"`
    Message string `json:"message"`
    TableID int    `json:"table_id"`
    UserID  int    `json:"user_id"`
}

func (h *TableHandler) JoinTable(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
        return
    }

    id, ok := extractTableID(strings.TrimSuffix(r.URL.Path, "/join"))
    if !ok {
        http.Error(w, "invalid table id", http.StatusBadRequest)
        return
    }

    var req JoinTableRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "invalid body", http.StatusBadRequest)
        return
    }

    if req.UserID <= 0 {
        http.Error(w, "invalid user_id", http.StatusBadRequest)
        return
    }

    var maxPlayers, currentPlayers int
    err := h.DB.QueryRow(`
        SELECT max_players, current_players
        FROM game_tables
        WHERE id = $1
    `, id).Scan(&maxPlayers, &currentPlayers)

    if err == sql.ErrNoRows {
        http.Error(w, "table not found", http.StatusNotFound)
        return
    }
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    if currentPlayers >= maxPlayers {
        http.Error(w, "table is full", http.StatusBadRequest)
        return
    }

    var exists int
    err = h.DB.QueryRow(`
        SELECT COUNT(1)
        FROM table_players
        WHERE table_id = $1 AND user_id = $2
    `, id, req.UserID).Scan(&exists)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    if exists > 0 {
        w.Header().Set("Content-Type", "application/json")
        json.NewEncoder(w).Encode(JoinTableResponse{
            Success: true,
            Message: "user already in table",
            TableID: id,
            UserID:  req.UserID,
        })
        return
    }

    tx, err := h.DB.Begin()
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    defer tx.Rollback()

    _, err = tx.Exec(`
        INSERT INTO table_players (table_id, user_id, seat_no, joined_at)
        VALUES ($1, $2, (
            SELECT COALESCE(MIN(s.seat_no), 1)
            FROM generate_series(1, 4) AS s(seat_no)
            WHERE s.seat_no NOT IN (
                SELECT seat_no FROM table_players WHERE table_id = $1
            )
        ), NOW())
    `, id, req.UserID)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    _, err = tx.Exec(`
        UPDATE game_tables
        SET current_players = current_players + 1
        WHERE id = $1
    `, id)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    if err := tx.Commit(); err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(JoinTableResponse{
        Success: true,
        Message: "joined table",
        TableID: id,
        UserID:  req.UserID,
    })
}

func extractTableID(path string) (int, bool) {
    parts := strings.Split(strings.Trim(path, "/"), "/")
    if len(parts) < 2 {
        return 0, false
    }

    id, err := strconv.Atoi(parts[1])
    if err != nil {
        return 0, false
    }

    return id, true
}
