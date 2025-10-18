import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/features/fantasy_advice/data/fantasy_advice_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Service provider
final fantasyAdviceServiceProvider = Provider<FantasyAdviceService>((ref) {
  return FantasyAdviceService(Supabase.instance.client);
});

// Fantasy advice provider
final fantasyAdviceProvider = FutureProvider.family<String, (String, String?)>((
  ref,
  params,
) async {
  final (query, context) = params;
  final service = ref.watch(fantasyAdviceServiceProvider);
  return service.getFantasyAdvice(query: query, context: context);
});

// Service availability provider
final serviceAvailabilityProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(fantasyAdviceServiceProvider);
  return service.isServiceAvailable();
});
