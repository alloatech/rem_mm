import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/features/leagues/data/leagues_service.dart';
import 'package:rem_mm/features/leagues/domain/league.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Leagues service provider
final leaguesServiceProvider = Provider<LeaguesService>((ref) {
  return LeaguesService(Supabase.instance.client);
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
