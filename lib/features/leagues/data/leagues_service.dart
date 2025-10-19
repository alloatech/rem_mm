import 'package:rem_mm/features/leagues/domain/league.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaguesService {
  final SupabaseClient _supabase;

  LeaguesService(this._supabase);

  /// Get all leagues for the current user
  Future<List<League>> getUserLeagues() async {
    try {
      // For now, use the hardcoded sleeper user ID for testing
      // In production, this would get the sleeper_user_id from authenticated user
      const sleeperUserId = '872612101674491904'; // th0rjc test user

      print('🔍 Fetching leagues for sleeper ID: $sleeperUserId');

      // Try direct query first to test database connectivity
      try {
        final directResponse = await _supabase.from('leagues').select('*').limit(1);
        print('🔗 Direct table query test: ${directResponse.length} records');
      } catch (e) {
        print('❌ Direct query failed: $e');
      }

      // Use the helper function that handles RLS automatically
      final response = await _supabase.rpc<List<dynamic>>(
        'get_user_leagues',
        params: {'p_sleeper_user_id': sleeperUserId},
      );

      print('🏈 Raw leagues response: $response');
      print('🏈 Response type: ${response.runtimeType}');
      print('🏈 Leagues count: ${response.length}');

      if (response.isEmpty) {
        print('⚠️ No leagues found for user $sleeperUserId');
        return [];
      }

      // Safely convert each item
      final leagues = <League>[];
      for (int i = 0; i < response.length; i++) {
        try {
          final json = response[i] as Map<String, dynamic>;
          print('🏈 Processing league $i: ${json['league_name']}');
          final league = League.fromJson(json);
          leagues.add(league);
        } catch (e) {
          print('❌ Error processing league $i: $e');
          print('❌ Raw data: ${response[i]}');
          // Continue processing other leagues
        }
      }

      print('✅ Successfully processed ${leagues.length} leagues');
      return leagues;
    } catch (e) {
      print('🔥 Error in getUserLeagues: $e');
      print('🔥 Error type: ${e.runtimeType}');
      print('🔥 Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Sync leagues from Sleeper API via the user-sync Edge Function
  Future<void> syncUserLeagues(String sleeperUserId) async {
    try {
      print('🔄 Starting league sync for user: $sleeperUserId');

      final response = await _supabase.functions.invoke(
        'user-sync',
        body: {'action': 'sync_leagues', 'sleeper_user_id': sleeperUserId},
      );

      print('📡 Sync response status: ${response.status}');
      print('📡 Sync response data: ${response.data}');

      if (response.status != 200 || response.data == null) {
        throw Exception('Failed to sync leagues: ${response.data ?? 'No response data'}');
      }

      print('✅ League sync completed successfully');
    } catch (error) {
      print('🔥 Error syncing leagues: $error');
      rethrow;
    }
  }

  /// Get leagues as simplified list items for UI display
  Future<List<LeagueListItem>> getUserLeaguesList() async {
    final leagues = await getUserLeagues();
    return leagues.map((league) => LeagueListItem.fromLeague(league)).toList();
  }

  /// Check if user has any leagues
  Future<bool> hasLeagues() async {
    try {
      final leagues = await getUserLeagues();
      return leagues.isNotEmpty;
    } catch (error) {
      print('🔥 Error checking leagues: $error');
      return false;
    }
  }
}
