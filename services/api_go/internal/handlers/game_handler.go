package handlers

import (
    "encoding/json"
    "net/http"
    "strconv"
    "strings"

    "okey101/services/api_go/internal/game101"
)

type GameHandler struct {
    Service *game101.Service
}

type StartGameRequest struct {
    TableID int64 `json:"table_id"`
    UserID  int64 `json:"user_id"`
}

type DrawRequest struct {
    UserID int64 `json:"user_id"`
}

type DiscardRequest struct {
    UserID int64  `json:"user_id"`
    TileID string `json:"tile_id"`
}

type OpenRequest struct {
    UserID int64 `json:"user_id"`
}

func NewGameHandler(service *game101.Service) *GameHandler {
    return &GameHandler{Service: service}
}

func (h *GameHandler) StartGame(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
        return
    }

    var req StartGameRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "invalid body", http.StatusBadRequest)
        return
    }

    if req.TableID <= 0 {
        http.Error(w, "invalid table_id", http.StatusBadRequest)
        return
    }

    result, err := h.Service.StartGame(req.TableID, req.UserID)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    writeJSON(w, http.StatusOK, result)
}

func (h *GameHandler) GetGame(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodGet {
        http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
        return
    }

    gameID, ok := extractGameID(r.URL.Path)
    if !ok {
        http.Error(w, "invalid game id", http.StatusBadRequest)
        return
    }

    viewerUserID, _ := strconv.ParseInt(r.URL.Query().Get("viewer_user_id"), 10, 64)

    view, err := h.Service.GetGame(gameID, viewerUserID)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    writeJSON(w, http.StatusOK, view)
}

func (h *GameHandler) DrawTile(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
        return
    }

    gameID, ok := extractGameID(strings.TrimSuffix(r.URL.Path, "/draw"))
    if !ok {
        http.Error(w, "invalid game id", http.StatusBadRequest)
        return
    }

    var req DrawRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "invalid body", http.StatusBadRequest)
        return
    }

    if req.UserID <= 0 {
        http.Error(w, "invalid user_id", http.StatusBadRequest)
        return
    }

    if err := h.Service.DrawTile(gameID, req.UserID); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }

    writeJSON(w, http.StatusOK, map[string]interface{}{
        "success": true,
        "message": "tas cekildi",
    })
}

func (h *GameHandler) DiscardTile(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
        return
    }

    gameID, ok := extractGameID(strings.TrimSuffix(r.URL.Path, "/discard"))
    if !ok {
        http.Error(w, "invalid game id", http.StatusBadRequest)
        return
    }

    var req DiscardRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "invalid body", http.StatusBadRequest)
        return
    }

    if req.UserID <= 0 || strings.TrimSpace(req.TileID) == "" {
        http.Error(w, "invalid discard payload", http.StatusBadRequest)
        return
    }

    if err := h.Service.DiscardTile(gameID, req.UserID, req.TileID); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }

    writeJSON(w, http.StatusOK, map[string]interface{}{
        "success": true,
        "message": "tas atildi",
    })
}

func (h *GameHandler) OpenHand(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
        return
    }

    gameID, ok := extractGameID(strings.TrimSuffix(r.URL.Path, "/open"))
    if !ok {
        http.Error(w, "invalid game id", http.StatusBadRequest)
        return
    }

    var req OpenRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "invalid body", http.StatusBadRequest)
        return
    }

    if req.UserID <= 0 {
        http.Error(w, "invalid user_id", http.StatusBadRequest)
        return
    }

    if err := h.Service.OpenHand(gameID, req.UserID); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }

    writeJSON(w, http.StatusOK, map[string]interface{}{
        "success": true,
        "message": "el acildi",
    })
}

func (h *GameHandler) RunBotTurns(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
        return
    }

    gameID, ok := extractGameID(strings.TrimSuffix(r.URL.Path, "/bot-turns"))
    if !ok {
        http.Error(w, "invalid game id", http.StatusBadRequest)
        return
    }

    if err := h.Service.RunBotTurns(gameID); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }

    writeJSON(w, http.StatusOK, map[string]interface{}{
        "success": true,
        "message": "bot turlari oynatildi",
    })
}

func extractGameID(path string) (int64, bool) {
    parts := strings.Split(strings.Trim(path, "/"), "/")
    if len(parts) < 2 {
        return 0, false
    }

    id, err := strconv.ParseInt(parts[1], 10, 64)
    if err != nil {
        return 0, false
    }

    return id, true
}
