import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/features/players/data/players_service.dart';
import 'package:rem_mm/features/players/domain/player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final playersServiceProvider = Provider<PlayersService>((ref) {
  return PlayersService(Supabase.instance.client);
});

// Use a String key (comma-separated IDs) instead of List to avoid reference equality issues
final rosterPlayersProvider = FutureProvider.autoDispose.family<List<Player>, String>((
  ref,
  playerIdsKey,
) async {
  final service = ref.watch(playersServiceProvider);
  // Convert comma-separated string back to list
  final playerIds = playerIdsKey.split(',');
  return service.getPlayersByIds(playerIds);
});
