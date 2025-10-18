import 'package:rem_mm/features/leagues/domain/league.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaguesService {
  final SupabaseClient _supabase;

  LeaguesService(this._supabase);

  /// Get all leagues for the current user
  Future<List<League>> getUserLeagues() async {
    // For now, use the hardcoded sleeper user ID for testing
    // In production, this would get the sleeper_user_id from authenticated user
    const sleeperUserId = '872612101674491904'; // th0rjc test user

    print('🔍 Looking up user profile for sleeper ID: $sleeperUserId');

    final profileResponse = await _supabase
        .from('app_users')
        .select('id')
        .eq('sleeper_user_id', sleeperUserId)
        .maybeSingle();

    print('👤 Profile response: $profileResponse');

    if (profileResponse == null) {
      throw Exception('User profile not found. Please ensure user is registered.');
    }

    final appUserId = profileResponse['id'] as String;
    print('🆔 App user ID: $appUserId');

    // Get leagues for this user
    final response = await _supabase
        .from('user_leagues')
        .select()
        .eq('app_user_id', appUserId)
        .eq('is_active', true)
        .order('season', ascending: false)
        .order('league_name');

    print('🏈 Leagues response: $response');
    print('🏈 Leagues count: ${(response as List).length}');

    return (response as List<dynamic>)
        .map((json) => League.fromJson(json as Map<String, dynamic>))
        .toList();
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

      if (response.status != 200) {
        throw Exception('Failed to sync leagues: ${response.data}');
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
