package game101

import (
    "database/sql"
    "encoding/json"
    "errors"
    "fmt"
    "math/rand"
    "sort"
    "time"
)

type Service struct {
    DB *sql.DB
}

type tableSeatSource struct {
    UserID      int64
    SeatNo      int
    DisplayName string
}

func NewService(db *sql.DB) *Service {
    return &Service{DB: db}
}

func (s *Service) StartGame(tableID int64, viewerUserID int64) (*StartGameResult, error) {
    seats, err := s.loadAndFillSeats(tableID)
    if err != nil {
        return nil, err
    }

    deck := buildDeck()
    shuffle(deck)

    indicator, deck := popIndicator(deck)
    okey := deriveOkey(indicator)
    deck = markSpecialTiles(deck, okey)

    for i := range seats {
        seats[i].Hand = []Tile{}
    }

    dealerSeat := 1
    currentTurnSeat := dealerSeat

    for round := 0; round < 21; round++ {
        for i := range seats {
            var drawn Tile
            drawn, deck = popTile(deck)
            seats[i].Hand = append(seats[i].Hand, drawn)
        }
    }

    for i := range seats {
        if seats[i].SeatNo == dealerSeat {
            var extra Tile
            extra, deck = popTile(deck)
            seats[i].Hand = append(seats[i].Hand, extra)
            break
        }
    }

    for i := range seats {
        seats[i].HandCount = len(seats[i].Hand)
    }

    indicatorJSON, _ := json.Marshal(indicator)
    okeyJSON, _ := json.Marshal(okey)
    drawPileJSON, _ := json.Marshal(deck)
    discardJSON, _ := json.Marshal([]Tile{})
    centerJSON, _ := json.Marshal([][]Tile{})

    var gameID int64
    err = s.DB.QueryRow(`
        INSERT INTO game_instances (
            table_id, status, dealer_seat, current_turn_seat, round_no,
            indicator_tile_json, okey_tile_json, draw_pile_json, discard_pile_json, center_melds_json
        )
        VALUES ($1, 'active', $2, $3, 1, $4, $5, $6, $7, $8)
        RETURNING id
    `,
        tableID,
        dealerSeat,
        currentTurnSeat,
        string(indicatorJSON),
        string(okeyJSON),
        string(drawPileJSON),
        string(discardJSON),
        string(centerJSON),
    ).Scan(&gameID)
    if err != nil {
        return nil, err
    }

    for _, seat := range seats {
        handJSON, _ := json.Marshal(seat.Hand)

        _, err := s.DB.Exec(`
            INSERT INTO game_instance_players (
                game_instance_id, user_id, seat_no, display_name, is_bot,
                hand_json, hand_count, has_opened, open_type, last_drawn_tile_id
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, FALSE, NULL, '')
        `,
            gameID,
            nullIfZero(seat.UserID),
            seat.SeatNo,
            seat.DisplayName,
            seat.IsBot,
            string(handJSON),
            len(seat.Hand),
        )
        if err != nil {
            return nil, err
        }
    }

    return &StartGameResult{
        GameID:  gameID,
        TableID: tableID,
        Status:  "active",
    }, nil
}

func (s *Service) GetGame(gameID int64, viewerUserID int64) (*GameStateView, error) {
    var (
        tableID         int64
        status          string
        dealerSeat      int
        currentTurnSeat int
        roundNo         int
        indicatorRaw    string
        okeyRaw         string
        drawRaw         string
        discardRaw      string
        centerRaw       string
    )

    err := s.DB.QueryRow(`
        SELECT
            table_id, status, dealer_seat, current_turn_seat, round_no,
            indicator_tile_json::text, okey_tile_json::text,
            draw_pile_json::text, discard_pile_json::text, center_melds_json::text
        FROM game_instances
        WHERE id = $1
    `, gameID).Scan(
        &tableID,
        &status,
        &dealerSeat,
        &currentTurnSeat,
        &roundNo,
        &indicatorRaw,
        &okeyRaw,
        &drawRaw,
        &discardRaw,
        &centerRaw,
    )
    if err != nil {
        return nil, err
    }

    var indicator Tile
    var okey Tile
    var drawPile []Tile
    var discardPile []Tile
    var centerMelds [][]Tile

    _ = json.Unmarshal([]byte(indicatorRaw), &indicator)
    _ = json.Unmarshal([]byte(okeyRaw), &okey)
    _ = json.Unmarshal([]byte(drawRaw), &drawPile)
    _ = json.Unmarshal([]byte(discardRaw), &discardPile)
    _ = json.Unmarshal([]byte(centerRaw), &centerMelds)

    rows, err := s.DB.Query(`
        SELECT
            COALESCE(user_id, 0),
            seat_no,
            display_name,
            is_bot,
            hand_json::text,
            hand_count,
            has_opened,
            COALESCE(open_type, ''),
            COALESCE(last_drawn_tile_id, '')
        FROM game_instance_players
        WHERE game_instance_id = $1
        ORDER BY seat_no ASC
    `, gameID)
    if err != nil {
        return nil, err
    }
    defer rows.Close()

    seats := make([]SeatView, 0)
    viewerHand := make([]Tile, 0)
    viewerSeatNo := 0
    viewerLastDrawnTileID := ""

    for rows.Next() {
        var (
            userID          int64
            seatNo          int
            displayName     string
            isBot           bool
            handRaw         string
            handCount       int
            hasOpened       bool
            openType        string
            lastDrawnTileID string
        )

        if err := rows.Scan(
            &userID,
            &seatNo,
            &displayName,
            &isBot,
            &handRaw,
            &handCount,
            &hasOpened,
            &openType,
            &lastDrawnTileID,
        ); err != nil {
            return nil, err
        }

        seats = append(seats, SeatView{
            UserID:      userID,
            SeatNo:      seatNo,
            DisplayName: displayName,
            IsBot:       isBot,
            HandCount:   handCount,
            HasOpened:   hasOpened,
            OpenType:    openType,
        })

        if userID == viewerUserID && viewerUserID > 0 {
            viewerSeatNo = seatNo
            viewerLastDrawnTileID = lastDrawnTileID
            _ = json.Unmarshal([]byte(handRaw), &viewerHand)
        }
    }

    return &GameStateView{
        GameID:          gameID,
        TableID:         tableID,
        Status:          status,
        RoundNo:         roundNo,
        DealerSeat:      dealerSeat,
        CurrentTurnSeat: currentTurnSeat,
        ViewerUserID:    viewerUserID,
        ViewerSeatNo:    viewerSeatNo,
        IndicatorTile:   indicator,
        OkeyTile:        okey,
        DrawPileCount:   len(drawPile),
        DiscardPile:     discardPile,
        CenterMelds:     centerMelds,
        Seats:           seats,
        ViewerHand:      viewerHand,
        ViewerLastDrawnTileID: viewerLastDrawnTileID,
    }, nil
}

func (s *Service) DrawTile(gameID int64, viewerUserID int64) error {
    tx, err := s.DB.Begin()
    if err != nil {
        return err
    }
    defer tx.Rollback()

    currentTurnSeat, err := s.currentTurnSeatTx(tx, gameID)
    if err != nil {
        return err
    }

    player, err := s.loadPlayerByUserTx(tx, gameID, viewerUserID)
    if err != nil {
        return err
    }

    if player.SeatNo != currentTurnSeat {
        return errors.New("sira sende degil")
    }

    if len(player.Hand) != 21 {
        return errors.New("once tas atman gerekiyor veya cekme hakkin yok")
    }

    drawPile, err := s.loadDrawPileTx(tx, gameID)
    if err != nil {
        return err
    }
    if len(drawPile) == 0 {
        return errors.New("cekilecek tas kalmadi")
    }

    var drawn Tile
    drawn, drawPile = popTile(drawPile)
    player.Hand = append(player.Hand, drawn)
    player.HandCount = len(player.Hand)
    player.LastDrawnTileID = drawn.ID

    if err := s.saveDrawPileTx(tx, gameID, drawPile); err != nil {
        return err
    }
    if err := s.savePlayerTx(tx, gameID, player); err != nil {
        return err
    }

    return tx.Commit()
}

func (s *Service) DiscardTile(gameID int64, viewerUserID int64, tileID string) error {
    tx, err := s.DB.Begin()
    if err != nil {
        return err
    }
    defer tx.Rollback()

    currentTurnSeat, err := s.currentTurnSeatTx(tx, gameID)
    if err != nil {
        return err
    }

    player, err := s.loadPlayerByUserTx(tx, gameID, viewerUserID)
    if err != nil {
        return err
    }

    if player.SeatNo != currentTurnSeat {
        return errors.New("sira sende degil")
    }

    if len(player.Hand) != 22 {
        return errors.New("tas atmak icin once cekmen gerekiyor")
    }

    index := -1
    var discarded Tile
    for i, t := range player.Hand {
        if t.ID == tileID {
            index = i
            discarded = t
            break
        }
    }
    if index < 0 {
        return errors.New("secilen tas elde bulunamadi")
    }

    player.Hand = append(player.Hand[:index], player.Hand[index+1:]...)
    player.HandCount = len(player.Hand)
    player.LastDrawnTileID = ""

    discardPile, err := s.loadDiscardPileTx(tx, gameID)
    if err != nil {
        return err
    }
    discardPile = append(discardPile, discarded)

    if err := s.saveDiscardPileTx(tx, gameID, discardPile); err != nil {
        return err
    }
    if err := s.savePlayerTx(tx, gameID, player); err != nil {
        return err
    }

    nextSeat := nextSeatNo(player.SeatNo)
    if _, err := tx.Exec(`
        UPDATE game_instances
        SET current_turn_seat = $2
        WHERE id = $1
    `, gameID, nextSeat); err != nil {
        return err
    }

    return tx.Commit()
}

func (s *Service) OpenHand(gameID int64, viewerUserID int64) error {
    tx, err := s.DB.Begin()
    if err != nil {
        return err
    }
    defer tx.Rollback()

    currentTurnSeat, err := s.currentTurnSeatTx(tx, gameID)
    if err != nil {
        return err
    }

    player, err := s.loadPlayerByUserTx(tx, gameID, viewerUserID)
    if err != nil {
        return err
    }

    if player.SeatNo != currentTurnSeat {
        return errors.New("sira sende degil")
    }
    if player.HasOpened {
        return errors.New("el zaten acildi")
    }
    if len(player.Hand) < 21 {
        return errors.New("elde gecersiz tas sayisi")
    }

    groups, total, usedIDs := bestOpenGroups(player.Hand)

    if total < 101 && !CanOpenWithPairs(player.Hand) {
        return errors.New("el acmak icin toplam 101 olmali veya 5 cift olmali")
    }

    center, err := s.loadCenterMeldsTx(tx, gameID)
    if err != nil {
        return err
    }
    center = append(center, groups...)

    newHand := make([]Tile, 0, len(player.Hand))
    for _, t := range player.Hand {
        if !usedIDs[t.ID] {
            newHand = append(newHand, t)
        }
    }

    player.Hand = newHand
    player.HandCount = len(newHand)
    player.HasOpened = true
    if CanOpenWithPairs(player.Hand) && total < 101 {
        player.OpenType = "pairs"
    } else {
        player.OpenType = "sum101"
    }
    player.LastDrawnTileID = ""

    if err := s.saveCenterMeldsTx(tx, gameID, center); err != nil {
        return err
    }
    if err := s.savePlayerTx(tx, gameID, player); err != nil {
        return err
    }

    return tx.Commit()
}

func (s *Service) RunBotTurns(gameID int64) error {
    for i := 0; i < 8; i++ {
        moved, err := s.runSingleBotTurn(gameID)
        if err != nil {
            return err
        }
        if !moved {
            return nil
        }
    }
    return nil
}

func (s *Service) runSingleBotTurn(gameID int64) (bool, error) {
    tx, err := s.DB.Begin()
    if err != nil {
        return false, err
    }
    defer tx.Rollback()

    currentTurnSeat, err := s.currentTurnSeatTx(tx, gameID)
    if err != nil {
        return false, err
    }

    player, err := s.loadPlayerBySeatTx(tx, gameID, currentTurnSeat)
    if err != nil {
        return false, err
    }

    if !player.IsBot {
        return false, nil
    }

    if len(player.Hand) == 21 {
        drawPile, err := s.loadDrawPileTx(tx, gameID)
        if err != nil {
            return false, err
        }
        if len(drawPile) == 0 {
            return false, errors.New("cekilecek tas kalmadi")
        }

        var drawn Tile
        drawn, drawPile = popTile(drawPile)
        player.Hand = append(player.Hand, drawn)
        player.HandCount = len(player.Hand)
        player.LastDrawnTileID = drawn.ID

        if err := s.saveDrawPileTx(tx, gameID, drawPile); err != nil {
            return false, err
        }
    }

    if !player.HasOpened {
        groups, total, usedIDs := bestOpenGroups(player.Hand)
        if total >= 101 || CanOpenWithPairs(player.Hand) {
            center, err := s.loadCenterMeldsTx(tx, gameID)
            if err != nil {
                return false, err
            }
            center = append(center, groups...)

            newHand := make([]Tile, 0, len(player.Hand))
            for _, t := range player.Hand {
                if !usedIDs[t.ID] {
                    newHand = append(newHand, t)
                }
            }

            player.Hand = newHand
            player.HandCount = len(newHand)
            player.HasOpened = true
            if total >= 101 {
                player.OpenType = "sum101"
            } else {
                player.OpenType = "pairs"
            }

            if err := s.saveCenterMeldsTx(tx, gameID, center); err != nil {
                return false, err
            }
        }
    }

    if len(player.Hand) == 0 {
        nextSeat := nextSeatNo(player.SeatNo)
        if _, err := tx.Exec(`UPDATE game_instances SET current_turn_seat = $2 WHERE id = $1`, gameID, nextSeat); err != nil {
            return false, err
        }
        if err := s.savePlayerTx(tx, gameID, player); err != nil {
            return false, err
        }
        if err := tx.Commit(); err != nil {
            return false, err
        }
        return true, nil
    }

    discardedIndex := leastUsefulTileIndex(player.Hand)
    discarded := player.Hand[discardedIndex]
    player.Hand = append(player.Hand[:discardedIndex], player.Hand[discardedIndex+1:]...)
    player.HandCount = len(player.Hand)
    player.LastDrawnTileID = ""

    discardPile, err := s.loadDiscardPileTx(tx, gameID)
    if err != nil {
        return false, err
    }
    discardPile = append(discardPile, discarded)

    if err := s.saveDiscardPileTx(tx, gameID, discardPile); err != nil {
        return false, err
    }
    if err := s.savePlayerTx(tx, gameID, player); err != nil {
        return false, err
    }

    nextSeat := nextSeatNo(player.SeatNo)
    if _, err := tx.Exec(`
        UPDATE game_instances
        SET current_turn_seat = $2
        WHERE id = $1
    `, gameID, nextSeat); err != nil {
        return false, err
    }

    if err := tx.Commit(); err != nil {
        return false, err
    }
    return true, nil
}

type runtimePlayer struct {
    UserID          int64
    SeatNo          int
    DisplayName     string
    IsBot           bool
    Hand            []Tile
    HandCount       int
    HasOpened       bool
    OpenType        string
    LastDrawnTileID string
}

func (s *Service) currentTurnSeatTx(tx *sql.Tx, gameID int64) (int, error) {
    var seat int
    err := tx.QueryRow(`SELECT current_turn_seat FROM game_instances WHERE id = $1`, gameID).Scan(&seat)
    return seat, err
}

func (s *Service) loadPlayerByUserTx(tx *sql.Tx, gameID int64, userID int64) (*runtimePlayer, error) {
    var (
        dbUserID        int64
        seatNo          int
        displayName     string
        isBot           bool
        handRaw         string
        handCount       int
        hasOpened       bool
        openType        string
        lastDrawnTileID string
    )
    err := tx.QueryRow(`
        SELECT
            COALESCE(user_id, 0),
            seat_no,
            display_name,
            is_bot,
            hand_json::text,
            hand_count,
            has_opened,
            COALESCE(open_type, ''),
            COALESCE(last_drawn_tile_id, '')
        FROM game_instance_players
        WHERE game_instance_id = $1 AND user_id = $2
        LIMIT 1
    `, gameID, userID).Scan(
        &dbUserID,
        &seatNo,
        &displayName,
        &isBot,
        &handRaw,
        &handCount,
        &hasOpened,
        &openType,
        &lastDrawnTileID,
    )
    if err != nil {
        return nil, err
    }

    var hand []Tile
    _ = json.Unmarshal([]byte(handRaw), &hand)

    return &runtimePlayer{
        UserID:          dbUserID,
        SeatNo:          seatNo,
        DisplayName:     displayName,
        IsBot:           isBot,
        Hand:            hand,
        HandCount:       handCount,
        HasOpened:       hasOpened,
        OpenType:        openType,
        LastDrawnTileID: lastDrawnTileID,
    }, nil
}

func (s *Service) loadPlayerBySeatTx(tx *sql.Tx, gameID int64, seatNo int) (*runtimePlayer, error) {
    var (
        dbUserID        int64
        displayName     string
        isBot           bool
        handRaw         string
        handCount       int
        hasOpened       bool
        openType        string
        lastDrawnTileID string
    )
    err := tx.QueryRow(`
        SELECT
            COALESCE(user_id, 0),
            display_name,
            is_bot,
            hand_json::text,
            hand_count,
            has_opened,
            COALESCE(open_type, ''),
            COALESCE(last_drawn_tile_id, '')
        FROM game_instance_players
        WHERE game_instance_id = $1 AND seat_no = $2
        LIMIT 1
    `, gameID, seatNo).Scan(
        &dbUserID,
        &displayName,
        &isBot,
        &handRaw,
        &handCount,
        &hasOpened,
        &openType,
        &lastDrawnTileID,
    )
    if err != nil {
        return nil, err
    }

    var hand []Tile
    _ = json.Unmarshal([]byte(handRaw), &hand)

    return &runtimePlayer{
        UserID:          dbUserID,
        SeatNo:          seatNo,
        DisplayName:     displayName,
        IsBot:           isBot,
        Hand:            hand,
        HandCount:       handCount,
        HasOpened:       hasOpened,
        OpenType:        openType,
        LastDrawnTileID: lastDrawnTileID,
    }, nil
}

func (s *Service) savePlayerTx(tx *sql.Tx, gameID int64, p *runtimePlayer) error {
    handJSON, _ := json.Marshal(p.Hand)
    _, err := tx.Exec(`
        UPDATE game_instance_players
        SET hand_json = $3, hand_count = $4, has_opened = $5, open_type = $6, last_drawn_tile_id = $7
        WHERE game_instance_id = $1 AND seat_no = $2
    `,
        gameID,
        p.SeatNo,
        string(handJSON),
        len(p.Hand),
        p.HasOpened,
        nullString(p.OpenType),
        p.LastDrawnTileID,
    )
    return err
}

func (s *Service) loadDrawPileTx(tx *sql.Tx, gameID int64) ([]Tile, error) {
    var raw string
    if err := tx.QueryRow(`SELECT draw_pile_json::text FROM game_instances WHERE id = $1`, gameID).Scan(&raw); err != nil {
        return nil, err
    }
    var pile []Tile
    _ = json.Unmarshal([]byte(raw), &pile)
    return pile, nil
}

func (s *Service) saveDrawPileTx(tx *sql.Tx, gameID int64, pile []Tile) error {
    raw, _ := json.Marshal(pile)
    _, err := tx.Exec(`UPDATE game_instances SET draw_pile_json = $2 WHERE id = $1`, gameID, string(raw))
    return err
}

func (s *Service) loadDiscardPileTx(tx *sql.Tx, gameID int64) ([]Tile, error) {
    var raw string
    if err := tx.QueryRow(`SELECT discard_pile_json::text FROM game_instances WHERE id = $1`, gameID).Scan(&raw); err != nil {
        return nil, err
    }
    var pile []Tile
    _ = json.Unmarshal([]byte(raw), &pile)
    return pile, nil
}

func (s *Service) saveDiscardPileTx(tx *sql.Tx, gameID int64, pile []Tile) error {
    raw, _ := json.Marshal(pile)
    _, err := tx.Exec(`UPDATE game_instances SET discard_pile_json = $2 WHERE id = $1`, gameID, string(raw))
    return err
}

func (s *Service) loadCenterMeldsTx(tx *sql.Tx, gameID int64) ([][]Tile, error) {
    var raw string
    if err := tx.QueryRow(`SELECT center_melds_json::text FROM game_instances WHERE id = $1`, gameID).Scan(&raw); err != nil {
        return nil, err
    }
    var melds [][]Tile
    _ = json.Unmarshal([]byte(raw), &melds)
    return melds, nil
}

func (s *Service) saveCenterMeldsTx(tx *sql.Tx, gameID int64, melds [][]Tile) error {
    raw, _ := json.Marshal(melds)
    _, err := tx.Exec(`UPDATE game_instances SET center_melds_json = $2 WHERE id = $1`, gameID, string(raw))
    return err
}

func (s *Service) loadAndFillSeats(tableID int64) ([]SeatRuntime, error) {
    rows, err := s.DB.Query(`
        SELECT tp.user_id, tp.seat_no, COALESCE(u.display_name, u.username)
        FROM table_players tp
        INNER JOIN users u ON u.id = tp.user_id
        WHERE tp.table_id = $1
        ORDER BY tp.seat_no ASC
    `, tableID)
    if err != nil {
        return nil, err
    }
    defer rows.Close()

    source := make([]tableSeatSource, 0)
    for rows.Next() {
        var s tableSeatSource
        if err := rows.Scan(&s.UserID, &s.SeatNo, &s.DisplayName); err != nil {
            return nil, err
        }
        source = append(source, s)
    }

    seatMap := map[int]SeatRuntime{}
    for _, s := range source {
        seatMap[s.SeatNo] = SeatRuntime{
            UserID:      s.UserID,
            SeatNo:      s.SeatNo,
            DisplayName: s.DisplayName,
            IsBot:       false,
            Hand:        []Tile{},
        }
    }

    for seatNo := 1; seatNo <= 4; seatNo++ {
        if _, ok := seatMap[seatNo]; !ok {
            seatMap[seatNo] = SeatRuntime{
                UserID:      0,
                SeatNo:      seatNo,
                DisplayName: fmt.Sprintf("Bot %d", seatNo),
                IsBot:       true,
                Hand:        []Tile{},
            }
        }
    }

    result := make([]SeatRuntime, 0, 4)
    for seatNo := 1; seatNo <= 4; seatNo++ {
        result = append(result, seatMap[seatNo])
    }
    return result, nil
}

func buildDeck() []Tile {
    colors := []string{"red", "blue", "black", "yellow"}
    deck := make([]Tile, 0, 106)

    for copyNo := 1; copyNo <= 2; copyNo++ {
        for _, color := range colors {
            for value := 1; value <= 13; value++ {
                deck = append(deck, Tile{
                    ID:    fmt.Sprintf("%s-%d-%d", color, value, copyNo),
                    Color: color,
                    Value: value,
                    Kind:  "normal",
                })
            }
        }
    }

    deck = append(deck, Tile{
        ID:         "fake-okey-1",
        Color:      "fake",
        Value:      0,
        Kind:       "fake_okey",
        IsFakeOkey: true,
    })
    deck = append(deck, Tile{
        ID:         "fake-okey-2",
        Color:      "fake",
        Value:      0,
        Kind:       "fake_okey",
        IsFakeOkey: true,
    })

    return deck
}

func shuffle(deck []Tile) {
    r := rand.New(rand.NewSource(time.Now().UnixNano()))
    r.Shuffle(len(deck), func(i, j int) {
        deck[i], deck[j] = deck[j], deck[i]
    })
}

func popTile(deck []Tile) (Tile, []Tile) {
    if len(deck) == 0 {
        return Tile{}, deck
    }
    return deck[len(deck)-1], deck[:len(deck)-1]
}

func popIndicator(deck []Tile) (Tile, []Tile) {
    for {
        t, rest := popTile(deck)
        deck = rest
        if !t.IsFakeOkey {
            return t, deck
        }
    }
}

func deriveOkey(indicator Tile) Tile {
    nextValue := indicator.Value + 1
    if nextValue > 13 {
        nextValue = 1
    }
    return Tile{
        ID:     fmt.Sprintf("okey-%s-%d", indicator.Color, nextValue),
        Color:  indicator.Color,
        Value:  nextValue,
        Kind:   "normal",
        IsOkey: true,
    }
}

func markSpecialTiles(deck []Tile, okey Tile) []Tile {
    out := make([]Tile, 0, len(deck))
    for _, t := range deck {
        if t.IsFakeOkey {
            out = append(out, t)
            continue
        }
        if t.Color == okey.Color && t.Value == okey.Value {
            t.IsOkey = true
        }
        out = append(out, t)
    }
    return out
}

func bestOpenGroups(hand []Tile) ([][]Tile, int, map[string]bool) {
    candidates := make([][]Tile, 0)
    candidates = append(candidates, findRunCandidates(hand)...)
    candidates = append(candidates, findSetCandidates(hand)...)

    sort.Slice(candidates, func(i, j int) bool {
        if len(candidates[i]) != len(candidates[j]) {
            return len(candidates[i]) > len(candidates[j])
        }
        return sumTiles(candidates[i]) > sumTiles(candidates[j])
    })

    used := map[string]bool{}
    chosen := make([][]Tile, 0)
    total := 0

    for _, group := range candidates {
        conflict := false
        for _, t := range group {
            if used[t.ID] {
                conflict = true
                break
            }
        }
        if conflict {
            continue
        }

        chosen = append(chosen, group)
        total += sumTiles(group)
        for _, t := range group {
            used[t.ID] = true
        }
    }

    return chosen, total, used
}

func findRunCandidates(hand []Tile) [][]Tile {
    byColor := map[string][]Tile{}
    for _, t := range hand {
        if t.IsOkey || t.IsFakeOkey {
            continue
        }
        byColor[t.Color] = append(byColor[t.Color], t)
    }

    result := make([][]Tile, 0)
    for _, tiles := range byColor {
        sort.Slice(tiles, func(i, j int) bool {
            return tiles[i].Value < tiles[j].Value
        })

        current := make([]Tile, 0)
        lastValue := -1

        for _, t := range tiles {
            if len(current) == 0 {
                current = append(current, t)
                lastValue = t.Value
                continue
            }

            if t.Value == lastValue+1 {
                current = append(current, t)
                lastValue = t.Value
            } else if t.Value == lastValue {
                continue
            } else {
                if len(current) >= 3 {
                    cp := append([]Tile{}, current...)
                    result = append(result, cp)
                }
                current = []Tile{t}
                lastValue = t.Value
            }
        }

        if len(current) >= 3 {
            cp := append([]Tile{}, current...)
            result = append(result, cp)
        }
    }
    return result
}

func findSetCandidates(hand []Tile) [][]Tile {
    byValue := map[int]map[string]Tile{}
    for _, t := range hand {
        if t.IsOkey || t.IsFakeOkey {
            continue
        }
        if _, ok := byValue[t.Value]; !ok {
            byValue[t.Value] = map[string]Tile{}
        }
        if _, ok := byValue[t.Value][t.Color]; !ok {
            byValue[t.Value][t.Color] = t
        }
    }

    result := make([][]Tile, 0)
    for _, colorMap := range byValue {
        if len(colorMap) >= 3 {
            group := make([]Tile, 0, len(colorMap))
            for _, tile := range colorMap {
                group = append(group, tile)
            }
            sort.Slice(group, func(i, j int) bool {
                return group[i].Color < group[j].Color
            })
            result = append(result, group)
        }
    }
    return result
}

func sumTiles(group []Tile) int {
    total := 0
    for _, t := range group {
        if !t.IsOkey && !t.IsFakeOkey {
            total += t.Value
        }
    }
    return total
}

func leastUsefulTileIndex(hand []Tile) int {
    if len(hand) == 0 {
        return 0
    }

    bestIndex := 0
    bestScore := 999999

    for i, t := range hand {
        score := t.Value

        if t.IsOkey || t.IsFakeOkey {
            score += 1000
        }

        neighborCount := 0
        sameValueColors := 0

        for j, other := range hand {
            if i == j {
                continue
            }
            if other.Color == t.Color && (other.Value == t.Value-1 || other.Value == t.Value+1) {
                neighborCount++
            }
            if other.Value == t.Value && other.Color != t.Color {
                sameValueColors++
            }
        }

        score -= neighborCount * 10
        score -= sameValueColors * 8

        if score < bestScore {
            bestScore = score
            bestIndex = i
        }
    }

    return bestIndex
}

func nullIfZero(v int64) interface{} {
    if v == 0 {
        return nil
    }
    return v
}

func nullString(v string) interface{} {
    if v == "" {
        return nil
    }
    return v
}

func nextSeatNo(seat int) int {
    seat++
    if seat > 4 {
        return 1
    }
    return seat
}
