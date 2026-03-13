package handlers

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
)

type TableHandler struct {
	DB *sql.DB
}

func NewTableHandler(db *sql.DB) *TableHandler {
	return &TableHandler{DB: db}
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

type JoinTableRequest struct {
	UserID int `json:"user_id"`
}

type JoinTableResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	TableID int    `json:"table_id"`
	UserID  int    `json:"user_id"`
}

type LeaveTableRequest struct {
	UserID int `json:"user_id"`
}

type CreateTableRequest struct {
	UserID     int    `json:"user_id"`
	Name       string `json:"name"`
	GameType   string `json:"game_type"`
	MaxPlayers int    `json:"max_players"`
	MinBuyIn   int    `json:"min_buy_in"`
}

func (h *TableHandler) ListTables(w http.ResponseWriter, r *http.Request) {
	if err := h.cleanupTablesWithoutRealPlayers(); err != nil {
		http.Error(w, "failed to cleanup tables", http.StatusInternalServerError)
		return
	}

	rows, err := h.DB.Query(`
        SELECT
            gt.id,
            COALESCE(NULLIF(gt.name, ''), gt.table_name) AS visible_name,
            gt.game_type,
            gt.max_players,
            gt.current_players,
            gt.stake_amount,
            gt.status
        FROM game_tables gt
        ORDER BY gt.id
    `)
	if err != nil {
		http.Error(w, "failed to query tables", http.StatusInternalServerError)
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
			http.Error(w, "failed to scan tables", http.StatusInternalServerError)
			return
		}
		tables = append(tables, t)
	}

	writeHandlerJSON(w, http.StatusOK, map[string]interface{}{
		"tables": tables,
	})
}

func (h *TableHandler) GetTable(w http.ResponseWriter, r *http.Request) {
	tableID, err := parseTableID(r.URL.Path)
	if err != nil {
		http.Error(w, "invalid table id", http.StatusBadRequest)
		return
	}

	var t TableDTO
	err = h.DB.QueryRow(`
        SELECT
            id,
            COALESCE(NULLIF(name, ''), table_name) AS visible_name,
            game_type,
            max_players,
            current_players,
            stake_amount,
            status
        FROM game_tables
        WHERE id = $1
    `, tableID).Scan(
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
		http.Error(w, "failed to query table", http.StatusInternalServerError)
		return
	}

	playerRows, err := h.DB.Query(`
        SELECT tp.user_id, u.username, u.display_name, tp.seat_no
        FROM table_players tp
        JOIN users u ON u.id = tp.user_id
        WHERE tp.table_id = $1 AND tp.is_active = TRUE
        ORDER BY tp.seat_no
    `, tableID)
	if err != nil {
		http.Error(w, "failed to query players", http.StatusInternalServerError)
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
			http.Error(w, "failed to scan players", http.StatusInternalServerError)
			return
		}
		players = append(players, p)
	}

	t.Players = players
	t.CurrentPlayers = len(players)

	writeHandlerJSON(w, http.StatusOK, t)
}

func (h *TableHandler) CreateTable(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req CreateTableRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}

	if req.UserID <= 0 {
		http.Error(w, "user_id required", http.StatusBadRequest)
		return
	}

	name := strings.TrimSpace(req.Name)
	if name == "" {
		name = "Yeni Masa"
	}

	gameType := strings.TrimSpace(req.GameType)
	if gameType == "" {
		gameType = "101"
	}

	maxPlayers := req.MaxPlayers
	if maxPlayers <= 0 {
		maxPlayers = 4
	}

	stakeAmount := req.MinBuyIn
	if stakeAmount < 0 {
		stakeAmount = 0
	}

	tx, err := h.DB.Begin()
	if err != nil {
		http.Error(w, "failed to begin transaction", http.StatusInternalServerError)
		return
	}
	defer tx.Rollback()

	var tableID int
	err = tx.QueryRow(`
        INSERT INTO game_tables (
            table_name,
            game_type,
            mode_type,
            stake_amount,
            max_players,
            current_players,
            status,
            created_by_user_id,
            name
        )
        VALUES ($1, $2, $3, $4, $5, $6, 'waiting', $7, $8)
        RETURNING id
    `, name, gameType, "standard", stakeAmount, maxPlayers, 1, req.UserID, name).Scan(&tableID)
	if err != nil {
		http.Error(w, "failed to create table", http.StatusInternalServerError)
		return
	}

	_, err = tx.Exec(`
        INSERT INTO table_players (table_id, user_id, seat_no, is_active)
        VALUES ($1, $2, 1, TRUE)
    `, tableID, req.UserID)
	if err != nil {
		http.Error(w, "failed to join creator to table", http.StatusInternalServerError)
		return
	}

	if err := tx.Commit(); err != nil {
		http.Error(w, "failed to commit transaction", http.StatusInternalServerError)
		return
	}

	writeHandlerJSON(w, http.StatusCreated, map[string]interface{}{
		"success":  true,
		"message":  "table created",
		"table_id": tableID,
	})
}

func (h *TableHandler) JoinTable(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	tableID, err := parseTableID(r.URL.Path)
	if err != nil {
		http.Error(w, "invalid table id", http.StatusBadRequest)
		return
	}

	var req JoinTableRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}

	if req.UserID <= 0 {
		http.Error(w, "user_id required", http.StatusBadRequest)
		return
	}

	tx, err := h.DB.Begin()
	if err != nil {
		http.Error(w, "failed to begin transaction", http.StatusInternalServerError)
		return
	}
	defer tx.Rollback()

	var maxPlayers int
	err = tx.QueryRow(`SELECT max_players FROM game_tables WHERE id = $1`, tableID).Scan(&maxPlayers)
	if err == sql.ErrNoRows {
		http.Error(w, "table not found", http.StatusNotFound)
		return
	}
	if err != nil {
		http.Error(w, "failed to query table", http.StatusInternalServerError)
		return
	}

	var existingSeat int
	err = tx.QueryRow(`
        SELECT seat_no
        FROM table_players
        WHERE table_id = $1 AND user_id = $2 AND is_active = TRUE
    `, tableID, req.UserID).Scan(&existingSeat)
	if err == nil {
		if err := tx.Commit(); err != nil {
			http.Error(w, "failed to commit transaction", http.StatusInternalServerError)
			return
		}
		writeHandlerJSON(w, http.StatusOK, JoinTableResponse{
			Success: true,
			Message: "already joined",
			TableID: tableID,
			UserID:  req.UserID,
		})
		return
	}
	if err != nil && err != sql.ErrNoRows {
		http.Error(w, "failed to query existing player", http.StatusInternalServerError)
		return
	}

	rows, err := tx.Query(`
        SELECT seat_no
        FROM table_players
        WHERE table_id = $1 AND is_active = TRUE
        ORDER BY seat_no
    `, tableID)
	if err != nil {
		http.Error(w, "failed to query seats", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	usedSeats := make(map[int]bool)
	activeCount := 0
	for rows.Next() {
		var seat int
		if err := rows.Scan(&seat); err != nil {
			http.Error(w, "failed to scan seats", http.StatusInternalServerError)
			return
		}
		usedSeats[seat] = true
		activeCount++
	}

	seatToUse := 0
	for i := 1; i <= maxPlayers; i++ {
		if !usedSeats[i] {
			seatToUse = i
			break
		}
	}

	if seatToUse == 0 {
		http.Error(w, "table is full", http.StatusConflict)
		return
	}

	_, err = tx.Exec(`
        INSERT INTO table_players (table_id, user_id, seat_no, is_active)
        VALUES ($1, $2, $3, TRUE)
    `, tableID, req.UserID, seatToUse)
	if err != nil {
		http.Error(w, "failed to join table", http.StatusInternalServerError)
		return
	}

	_, err = tx.Exec(`
        UPDATE game_tables
        SET current_players = $2
        WHERE id = $1
    `, tableID, activeCount+1)
	if err != nil {
		http.Error(w, "failed to update table player count", http.StatusInternalServerError)
		return
	}

	if err := tx.Commit(); err != nil {
		http.Error(w, "failed to commit transaction", http.StatusInternalServerError)
		return
	}

	writeHandlerJSON(w, http.StatusOK, JoinTableResponse{
		Success: true,
		Message: "joined table",
		TableID: tableID,
		UserID:  req.UserID,
	})
}

func (h *TableHandler) LeaveTable(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	tableID, err := parseTableID(r.URL.Path)
	if err != nil {
		http.Error(w, "invalid table id", http.StatusBadRequest)
		return
	}

	var req LeaveTableRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}

	if req.UserID <= 0 {
		http.Error(w, "user_id required", http.StatusBadRequest)
		return
	}

	_, err = h.DB.Exec(`
        UPDATE table_players
        SET is_active = FALSE, left_at = NOW()
        WHERE table_id = $1 AND user_id = $2 AND is_active = TRUE
    `, tableID, req.UserID)
	if err != nil {
		http.Error(w, "failed to leave table", http.StatusInternalServerError)
		return
	}

	var activeCount int
	err = h.DB.QueryRow(`
        SELECT COUNT(*)
        FROM table_players
        WHERE table_id = $1 AND is_active = TRUE
    `, tableID).Scan(&activeCount)
	if err != nil {
		http.Error(w, "failed to count active players", http.StatusInternalServerError)
		return
	}

	_, err = h.DB.Exec(`
        UPDATE game_tables
        SET current_players = $2
        WHERE id = $1
    `, tableID, activeCount)
	if err != nil {
		http.Error(w, "failed to update table player count", http.StatusInternalServerError)
		return
	}

	if err := h.cleanupSingleTableIfNoRealPlayers(tableID); err != nil {
		http.Error(w, "failed to cleanup table", http.StatusInternalServerError)
		return
	}

	writeHandlerJSON(w, http.StatusOK, map[string]interface{}{
		"success":  true,
		"message":  "left table",
		"table_id": tableID,
		"user_id":  req.UserID,
	})
}

func (h *TableHandler) cleanupTablesWithoutRealPlayers() error {
	rows, err := h.DB.Query(`
        SELECT gt.id
        FROM game_tables gt
        WHERE NOT EXISTS (
            SELECT 1
            FROM table_players tp
            JOIN users u ON u.id = tp.user_id
            WHERE tp.table_id = gt.id
              AND tp.is_active = TRUE
              AND u.username NOT LIKE 'bot_%'
        )
    `)
	if err != nil {
		return err
	}
	defer rows.Close()

	ids := make([]int, 0)
	for rows.Next() {
		var id int
		if err := rows.Scan(&id); err != nil {
			return err
		}
		ids = append(ids, id)
	}

	for _, id := range ids {
		if _, err := h.DB.Exec(`DELETE FROM table_players WHERE table_id = $1`, id); err != nil {
			return err
		}
		if _, err := h.DB.Exec(`DELETE FROM game_tables WHERE id = $1`, id); err != nil {
			return err
		}
	}

	return nil
}

func (h *TableHandler) cleanupSingleTableIfNoRealPlayers(tableID int) error {
	var realCount int
	err := h.DB.QueryRow(`
        SELECT COUNT(*)
        FROM table_players tp
        JOIN users u ON u.id = tp.user_id
        WHERE tp.table_id = $1
          AND tp.is_active = TRUE
          AND u.username NOT LIKE 'bot_%'
    `, tableID).Scan(&realCount)
	if err != nil {
		return err
	}

	if realCount > 0 {
		return nil
	}

	if _, err := h.DB.Exec(`DELETE FROM table_players WHERE table_id = $1`, tableID); err != nil {
		return err
	}
	if _, err := h.DB.Exec(`DELETE FROM game_tables WHERE id = $1`, tableID); err != nil {
		return err
	}

	return nil
}

func parseTableID(path string) (int, error) {
	path = strings.Trim(path, "/")
	parts := strings.Split(path, "/")
	if len(parts) < 2 {
		return 0, fmt.Errorf("invalid path")
	}
	return strconv.Atoi(parts[1])
}

func writeHandlerJSON(w http.ResponseWriter, status int, payload interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}
