import 'package:rem_mm/features/profile/domain/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final SupabaseClient _supabase;

  ProfileService(this._supabase);

  /// Test database connectivity and user existence
  Future<Map<String, dynamic>> testUserLookup(String sleeperUserId) async {
    try {
      // Use our custom database function that handles RLS context properly
      final response = await _supabase.rpc<List<dynamic>>(
        'get_user_profile',
        params: {'target_sleeper_user_id': sleeperUserId},
      );

      return {
        'success': true,
        'user_exists': response.isNotEmpty,
        'raw_data': response.isNotEmpty ? response.first : null,
        'sleeper_user_id_query': sleeperUserId,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'sleeper_user_id_query': sleeperUserId,
      };
    }
  }

  /// Get current user's profile
  Future<UserProfile?> getCurrentUserProfile(String sleeperUserId) async {
    try {
      print('🔍 ProfileService: Querying for sleeper_user_id: $sleeperUserId');

      // Use our custom database function that handles RLS context properly
      final response = await _supabase.rpc<List<dynamic>>(
        'get_user_profile',
        params: {'target_sleeper_user_id': sleeperUserId},
      );

      print('🔍 ProfileService: Database response: $response');

      if (response.isEmpty) {
        print('❌ ProfileService: No user found in database');
        return null;
      }

      final userData = response.first as Map<String, dynamic>;

      // Transform database fields to match UserProfile expectations
      final transformedData = <String, dynamic>{
        'sleeper_user_id': userData['sleeper_user_id'],
        'sleeper_username': userData['sleeper_username'],
        'display_name': userData['display_name'],
        'email': userData['email'],
        'avatar_url': userData['avatar'] != null
            ? getSleeperAvatarUrl(userData['avatar'] as String?)
            : null,
        'status': userData['is_active'] == true ? 'active' : 'inactive',
        'created_at': userData['created_at'],
        'last_login': userData['last_login'],
        'preferences': null, // Not available in current schema
      };

      print('🔍 ProfileService: Transformed data: $transformedData');

      final userProfile = UserProfile.fromJson(transformedData);
      print('✅ ProfileService: Created UserProfile: ${userProfile.sleeperUsername}');
      return userProfile;
    } catch (e) {
      print('❌ ProfileService: Error: $e');
      throw Exception('Failed to get user profile: $e');
    }
  }

  /// Update current user's profile
  Future<UserProfile> updateProfile(
    String sleeperUserId,
    ProfileUpdateRequest request,
  ) async {
    try {
      final updateData = request.toJson();
      updateData['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('app_users')
          .update(updateData)
          .eq('sleeper_user_id', sleeperUserId)
          .select()
          .single();

      // Transform database fields to match UserProfile expectations
      final transformedData = <String, dynamic>{
        'sleeper_user_id': response['sleeper_user_id'],
        'sleeper_username': response['sleeper_username'],
        'display_name': response['display_name'],
        'email': response['email'],
        'avatar_url': response['avatar'] != null
            ? getSleeperAvatarUrl(response['avatar'] as String?)
            : null,
        'status': response['is_active'] == true ? 'active' : 'inactive',
        'created_at': response['created_at'],
        'last_login': response['last_login'],
        'preferences': response['preferences'],
      };

      return UserProfile.fromJson(transformedData);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  /// Get user's Sleeper avatar URL
  String getSleeperAvatarUrl(String? avatarId) {
    if (avatarId == null || avatarId.isEmpty) {
      return 'https://sleepercdn.com/avatars/thumbs/default_avatar.png';
    }
    return 'https://sleepercdn.com/avatars/thumbs/$avatarId';
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }
}
