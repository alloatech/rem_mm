-- Migration: Create live_roster_player_points table

CREATE TYPE roster_section AS ENUM ('starters', 'bench', 'injured reserve');

CREATE TABLE live_roster_player_points (
    id SERIAL PRIMARY KEY,
    league_id BIGINT NOT NULL,
    roster_id INTEGER NOT NULL,
    week INTEGER NOT NULL,
    player_id BIGINT NOT NULL,
    points NUMERIC(6,2) NOT NULL,
    section roster_section NOT NULL,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE (league_id, roster_id, week, player_id)
);

CREATE INDEX idx_live_roster_player_points_league_roster_week
    ON live_roster_player_points (league_id, roster_id, week);

CREATE INDEX idx_live_roster_player_points_section
    ON live_roster_player_points (section);
