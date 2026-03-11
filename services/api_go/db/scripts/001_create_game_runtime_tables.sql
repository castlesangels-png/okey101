CREATE TABLE IF NOT EXISTS game_instances (
    id BIGSERIAL PRIMARY KEY,
    table_id BIGINT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    dealer_seat INT NOT NULL,
    current_turn_seat INT NOT NULL,
    round_no INT NOT NULL DEFAULT 1,
    indicator_tile_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    okey_tile_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    draw_pile_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    discard_pile_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    center_melds_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS game_instance_players (
    id BIGSERIAL PRIMARY KEY,
    game_instance_id BIGINT NOT NULL REFERENCES game_instances(id) ON DELETE CASCADE,
    user_id BIGINT NULL,
    seat_no INT NOT NULL,
    display_name TEXT NOT NULL,
    is_bot BOOLEAN NOT NULL DEFAULT FALSE,
    hand_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    hand_count INT NOT NULL DEFAULT 0,
    has_opened BOOLEAN NOT NULL DEFAULT FALSE,
    open_type TEXT NULL,
    UNIQUE(game_instance_id, seat_no)
);
