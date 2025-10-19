import 'package:rem_mm/core/config/env.dart';
import 'package:rem_mm/features/leagues/data/leagues_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print('🔧 Starting leagues debug...');

  try {
    // Initialize Supabase
    await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);

    print('✅ Supabase initialized');

    // Test the leagues service
    final service = LeaguesService(Supabase.instance.client);

    print('🔍 Testing getUserLeagues...');
    final leagues = await service.getUserLeagues();

    print('✅ Success! Found ${leagues.length} leagues');
    for (final league in leagues) {
      print('  - ${league.leagueName} (${league.season})');
    }
  } catch (e, stack) {
    print('❌ Error: $e');
    print('Stack: $stack');
  }
}
