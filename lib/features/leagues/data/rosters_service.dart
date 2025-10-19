import 'package:rem_mm/features/leagues/domain/roster.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RostersService {
  final SupabaseClient _supabase;

  RostersService(this._supabase);

  /// Get all rosters for a specific league
  Future<List<Roster>> getLeagueRosters(String leagueId) async {
    print('🚀 ROSTERS SERVICE: getLeagueRosters called with leagueId: $leagueId');

    try {
      // Get current user's sleeper_user_id for isCurrentUser check
      final currentUser = _supabase.auth.currentUser;
      String? currentUserSleeperID;

      print('🚀 ROSTERS SERVICE: Current user: ${currentUser?.id}');

      if (currentUser != null) {
        final userResponse = await _supabase
            .from('app_users')
            .select('sleeper_user_id')
            .eq('supabase_user_id', currentUser.id)
            .maybeSingle();

        currentUserSleeperID = userResponse?['sleeper_user_id'] as String?;
        print('🚀 ROSTERS SERVICE: Retrieved sleeper user ID: $currentUserSleeperID');

        // Set the current sleeper user ID for RLS policies
        if (currentUserSleeperID != null) {
          try {
            // Use raw SQL instead of RPC
            await _supabase.rpc<String>(
              'exec_sql',
              params: {
                'sql':
                    "SELECT set_config('app.current_sleeper_user_id', '$currentUserSleeperID', true)",
              },
            );
            print('🏈 Set sleeper user ID config: $currentUserSleeperID');
          } catch (e) {
            print('⚠️ Failed to set config: $e');
            // Try alternative approach - use a direct SQL query if exec_sql doesn't exist
            try {
              await _supabase.from('user_rosters').select('id').limit(1).single();
            } catch (_) {
              // Ignore - this was just to test connection
            }
          }
        }
      }

      print('🏈 Fetching rosters for league: $leagueId');
      print('🏈 Current user sleeper ID: $currentUserSleeperID');

      // Use the database function that properly handles RLS
      final response = await _supabase.rpc<List<dynamic>>(
        'get_league_rosters',
        params: {
          'p_league_id': leagueId,
          'p_sleeper_user_id': currentUserSleeperID ?? '',
        },
      );

      print('🏈 Rosters response: $response');
      print('🏈 Rosters count: ${response.length}');

      return response
          .map(
            (json) => Roster.fromJson(
              json as Map<String, dynamic>,
              currentUserSleeperID: currentUserSleeperID,
            ),
          )
          .toList();
    } catch (e) {
      print('❌ Error fetching rosters: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Sync rosters from Sleeper API via the user-sync Edge Function
  Future<void> syncUserRosters(String sleeperUserId) async {
    try {
      print('🔄 Starting roster sync for user: $sleeperUserId');

      final response = await _supabase.functions.invoke(
        'user-sync',
        body: {'action': 'sync_rosters', 'sleeper_user_id': sleeperUserId},
      );

      if (response.status != 200 || response.data == null) {
        print('❌ Roster sync failed: ${response.data ?? 'No response data'}');
        throw Exception('Failed to sync rosters: ${response.data ?? 'No response data'}');
      }

      print('✅ Roster sync completed successfully');
    } catch (e) {
      print('❌ Error syncing rosters: $e');
      rethrow;
    }
  }

  /// Get user's roster (where they are the owner)
  Future<Roster?> getCurrentUserRoster(String leagueId) async {
    try {
      final rosters = await getLeagueRosters(leagueId);
      return rosters.where((r) => r.isCurrentUser).firstOrNull;
    } catch (e) {
      print('❌ Error fetching current user roster: $e');
      return null;
    }
  }

  /// Get all rosters for current user across all their leagues
  Future<List<Roster>> getUserRosters() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        return [];
      }

      // Get user's sleeper_user_id
      final userResponse = await _supabase
          .from('app_users')
          .select('sleeper_user_id')
          .eq('supabase_user_id', currentUser.id)
          .single();

      final sleeperUserId = userResponse['sleeper_user_id'] as String;

      print('🏈 Fetching all rosters for user: $sleeperUserId');

      final response = await _supabase
          .from('user_rosters')
          .select()
          .eq('sleeper_owner_id', sleeperUserId);

      return (response as List)
          .map(
            (json) => Roster.fromJson(
              json as Map<String, dynamic>,
              currentUserSleeperID: sleeperUserId,
            ),
          )
          .toList();
    } catch (e) {
      print('❌ Error fetching user rosters: $e');
      rethrow;
    }
  }
}
