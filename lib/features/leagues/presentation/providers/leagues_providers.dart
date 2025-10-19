import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/features/leagues/data/leagues_service.dart';
import 'package:rem_mm/features/leagues/data/rosters_service.dart';
import 'package:rem_mm/features/leagues/domain/league.dart';
import 'package:rem_mm/features/leagues/domain/roster.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Leagues service provider
final leaguesServiceProvider = Provider<LeaguesService>((ref) {
  return LeaguesService(Supabase.instance.client);
});

// Rosters service provider
final rostersServiceProvider = Provider<RostersService>((ref) {
  return RostersService(Supabase.instance.client);
});

// User leagues provider
final userLeaguesProvider = FutureProvider<List<League>>((ref) async {
  final service = ref.read(leaguesServiceProvider);
  return service.getUserLeagues();
});

// User leagues list provider (simplified for UI)
final userLeaguesListProvider = FutureProvider<List<LeagueListItem>>((ref) async {
  final service = ref.read(leaguesServiceProvider);
  return service.getUserLeaguesList();
});

// Has leagues provider
final hasLeaguesProvider = FutureProvider<bool>((ref) async {
  final service = ref.read(leaguesServiceProvider);
  return service.hasLeagues();
});

// League sync provider
final leagueSyncProvider = FutureProvider.family<void, String>((
  ref,
  sleeperUserId,
) async {
  final service = ref.read(leaguesServiceProvider);
  await service.syncUserLeagues(sleeperUserId);
  // Invalidate the leagues cache after sync
  ref.invalidate(userLeaguesProvider);
  ref.invalidate(userLeaguesListProvider);
  ref.invalidate(hasLeaguesProvider);
});

// Manual refresh provider for debugging
final refreshLeaguesProvider = FutureProvider<void>((ref) async {
  print('🔄 Manual refresh triggered');
  // Force refresh all league-related providers
  ref.invalidate(userLeaguesProvider);
  ref.invalidate(userLeaguesListProvider);
  ref.invalidate(hasLeaguesProvider);
});

// Roster providers

// League rosters provider (all rosters in a league)
final leagueRostersProvider = FutureProvider.family<List<Roster>, String>((
  ref,
  leagueId,
) async {
  final service = ref.read(rostersServiceProvider);
  return service.getLeagueRosters(leagueId);
});

// User's rosters across all leagues
final userRostersProvider = FutureProvider<List<Roster>>((ref) async {
  final service = ref.read(rostersServiceProvider);
  return service.getUserRosters();
});

// Current user's roster for a specific league
final currentUserRosterProvider = FutureProvider.family<Roster?, String>((
  ref,
  leagueId,
) async {
  final service = ref.read(rostersServiceProvider);
  return service.getCurrentUserRoster(leagueId);
});

// Roster sync provider
final rosterSyncProvider = FutureProvider.family<void, String>((
  ref,
  sleeperUserId,
) async {
  final service = ref.read(rostersServiceProvider);
  await service.syncUserRosters(sleeperUserId);
  // Invalidate roster caches after sync
  ref.invalidate(leagueRostersProvider);
  ref.invalidate(userRostersProvider);
  ref.invalidate(currentUserRosterProvider);
});

// Debug leagues provider
final debugLeaguesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.read(leaguesServiceProvider);
  try {
    final leagues = await service.getUserLeagues();
    return {
      'success': true,
      'leagues_count': leagues.length,
      'leagues': leagues.map((l) => l.leagueName).toList(),
    };
  } catch (error) {
    return {'success': false, 'error': error.toString()};
  }
});

// Selected league provider for navigation
final selectedLeagueProvider = Provider<League?>((ref) => null);
