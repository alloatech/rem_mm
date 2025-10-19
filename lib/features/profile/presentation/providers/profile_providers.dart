import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/features/profile/data/profile_service.dart';
import 'package:rem_mm/features/profile/domain/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Service provider
final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(Supabase.instance.client);
});

// Current user profile provider
final currentUserProfileProvider = FutureProvider.family<UserProfile?, String>((
  ref,
  sleeperUserId,
) async {
  final profileService = ref.watch(profileServiceProvider);
  return profileService.getCurrentUserProfile(sleeperUserId);
});

// Profile update provider
final profileUpdateProvider =
    FutureProvider.family<UserProfile, (String, ProfileUpdateRequest)>((
      ref,
      params,
    ) async {
      final (sleeperUserId, request) = params;
      final profileService = ref.watch(profileServiceProvider);
      final updatedProfile = await profileService.updateProfile(sleeperUserId, request);

      // Invalidate current profile to refresh
      ref.invalidate(currentUserProfileProvider(sleeperUserId));

      return updatedProfile;
    });

// Helper provider for Sleeper avatar URL
final sleeperAvatarUrlProvider = Provider.family<String, String?>((ref, avatarId) {
  final profileService = ref.watch(profileServiceProvider);
  return profileService.getSleeperAvatarUrl(avatarId);
});

// Test user lookup provider for debugging
final testUserLookupProvider = FutureProvider.family<Map<String, dynamic>, String>((
  ref,
  sleeperUserId,
) async {
  final profileService = ref.watch(profileServiceProvider);
  return profileService.testUserLookup(sleeperUserId);
});

// Sign out provider
final signOutProvider = FutureProvider<void>((ref) async {
  final profileService = ref.watch(profileServiceProvider);
  await profileService.signOut();

  // Clear all user-related providers
  ref.invalidate(currentUserProfileProvider);
});
