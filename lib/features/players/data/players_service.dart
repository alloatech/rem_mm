import 'package:rem_mm/features/players/domain/player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlayersService {
  final SupabaseClient _supabase;

  PlayersService(this._supabase);

  /// Fetch multiple players by IDs
  Future<List<Player>> getPlayersByIds(List<String> playerIds) async {
    try {
      if (playerIds.isEmpty) {
        return [];
      }

      final response = await _supabase
          .from('players_raw')
          .select()
          .inFilter('player_id', playerIds);

      if (response.isEmpty) {
        return [];
      }

      final players = (response as List<dynamic>)
          .map((json) => Player.fromJson(json as Map<String, dynamic>))
          .toList();

      return players;
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch a single player by ID
  Future<Player?> getPlayerById(String playerId) async {
    try {
      final response = await _supabase
          .from('players_raw')
          .select()
          .eq('player_id', playerId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      final player = Player.fromJson(response);
      return player;
    } catch (e) {
      rethrow;
    }
  }

  /// Search players by name
  Future<List<Player>> searchPlayers(String query) async {
    try {
      if (query.length < 2) {
        return [];
      }

      final response = await _supabase
          .from('players_raw')
          .select()
          .ilike('full_name', '%$query%')
          .limit(50);

      final players = (response as List<dynamic>)
          .map((json) => Player.fromJson(json as Map<String, dynamic>))
          .toList();

      return players;
    } catch (e) {
      rethrow;
    }
  }
}
