package game101

type Tile struct {
    ID         string `json:"id"`
    Color      string `json:"color"`
    Value      int    `json:"value"`
    Kind       string `json:"kind"`
    IsOkey     bool   `json:"is_okey"`
    IsFakeOkey bool   `json:"is_fake_okey"`
}

type SeatRuntime struct {
    UserID      int64  `json:"user_id"`
    SeatNo      int    `json:"seat_no"`
    DisplayName string `json:"display_name"`
    IsBot       bool   `json:"is_bot"`
    Hand        []Tile `json:"hand"`
    HandCount   int    `json:"hand_count"`
    HasOpened   bool   `json:"has_opened"`
    OpenType    string `json:"open_type"`
}

type SeatView struct {
    UserID      int64 `json:"user_id"`
    SeatNo      int   `json:"seat_no"`
    DisplayName string `json:"display_name"`
    IsBot       bool   `json:"is_bot"`
    HandCount   int    `json:"hand_count"`
    HasOpened   bool   `json:"has_opened"`
    OpenType    string `json:"open_type"`
}

type GameStateView struct {
    GameID          int64      `json:"game_id"`
    TableID         int64      `json:"table_id"`
    Status          string     `json:"status"`
    RoundNo         int        `json:"round_no"`
    DealerSeat      int        `json:"dealer_seat"`
    CurrentTurnSeat int        `json:"current_turn_seat"`
    ViewerUserID    int64      `json:"viewer_user_id"`
    ViewerSeatNo    int        `json:"viewer_seat_no"`
    IndicatorTile   Tile       `json:"indicator_tile"`
    OkeyTile        Tile       `json:"okey_tile"`
    DrawPileCount   int        `json:"draw_pile_count"`
    DiscardPile     []Tile     `json:"discard_pile"`
    CenterMelds     [][]Tile   `json:"center_melds"`
    Seats           []SeatView `json:"seats"`
    ViewerHand      []Tile     `json:"viewer_hand"`
    ViewerLastDrawnTileID string `json:"viewer_last_drawn_tile_id"`
}

type StartGameResult struct {
    GameID  int64  `json:"game_id"`
    TableID int64  `json:"table_id"`
    Status  string `json:"status"`
}
