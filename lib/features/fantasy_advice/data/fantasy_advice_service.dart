import 'package:supabase_flutter/supabase_flutter.dart';

class FantasyAdviceService {
  final SupabaseClient _supabase;
  static const String _fantasyAdviceFunction = 'hybrid-fantasy-advice';

  FantasyAdviceService(this._supabase);

  /// Get fantasy football advice using RAG pipeline
  Future<String> getFantasyAdvice({required String query, String? context}) async {
    try {
      final response = await _supabase.functions.invoke(
        _fantasyAdviceFunction,
        body: {'query': query, if (context != null) 'context': context},
      );

      if (response.data == null) {
        throw Exception('No response data received');
      }

      if (response.data['success'] != true) {
        throw Exception(response.data['error'] ?? 'Failed to get fantasy advice');
      }

      final advice = response.data['advice'];
      if (advice == null) {
        throw Exception('No advice received in response');
      }

      return advice as String;
    } catch (e) {
      throw Exception('Failed to get fantasy advice: $e');
    }
  }

  /// Check if the fantasy advice service is available
  Future<bool> isServiceAvailable() async {
    try {
      final response = await _supabase.functions.invoke(
        'hello', // Simple health check function
      );
      return response.data != null;
    } catch (e) {
      return false;
    }
  }
}
