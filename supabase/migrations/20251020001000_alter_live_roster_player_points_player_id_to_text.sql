-- Migration: Change player_id to TEXT in live_roster_player_points to support D/ST team abbreviations

ALTER TABLE live_roster_player_points ALTER COLUMN player_id TYPE TEXT;