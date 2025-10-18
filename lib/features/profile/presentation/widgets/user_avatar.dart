import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/features/profile/domain/user_profile.dart';
import 'package:rem_mm/features/profile/presentation/pages/profile_page.dart';
import 'package:rem_mm/features/profile/presentation/providers/profile_providers.dart';
import 'package:rem_mm/features/profile/presentation/widgets/profile_menu.dart';

class UserAvatar extends ConsumerWidget {
  final double size;
  final VoidCallback? onProfileTap;
  final VoidCallback? onSettingsTap;

  const UserAvatar({super.key, this.size = 32, this.onProfileTap, this.onSettingsTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sleeperUserId = ref.watch(currentSleeperUserIdProvider);

    if (sleeperUserId == null) {
      return CircleAvatar(radius: size / 2, child: const Icon(Icons.person));
    }

    final profileAsync = ref.watch(currentUserProfileProvider(sleeperUserId));

    return profileAsync.when(
      data: (profile) => GestureDetector(
        onTap: () => _showProfileMenu(context, profile),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: CircleAvatar(
            radius: size / 2 - 1,
            backgroundImage: profile?.avatarUrl != null
                ? NetworkImage(profile!.avatarUrl!)
                : null,
            child: profile?.avatarUrl == null
                ? Text(
                    profile?.sleeperUsername.substring(0, 1).toUpperCase() ?? 'T',
                    style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
        ),
      ),
      loading: () => GestureDetector(
        onTap: () => _showProfileMenu(context, null),
        child: CircleAvatar(
          radius: size / 2,
          child: SizedBox(
            width: size * 0.6,
            height: size * 0.6,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, stack) => GestureDetector(
        onTap: () => _showProfileMenu(context, _createFallbackProfile(sleeperUserId)),
        child: CircleAvatar(
          radius: size / 2,
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          child: Text(
            'T',
            style: TextStyle(
              fontSize: size * 0.4,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  void _showProfileMenu(BuildContext context, UserProfile? profile) {
    print('🔥 Avatar tapped! Profile: ${profile?.sleeperUsername ?? 'null'}');

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    print('📍 Position: $position, Size: $size');

    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          // Invisible barrier to dismiss
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.transparent,
            ),
          ),
          // Profile menu positioned near avatar
          Positioned(
            top: position.dy + size.height + 8,
            right: MediaQuery.of(context).size.width - position.dx - size.width,
            child: Material(
              color: Colors.transparent,
              child: ProfileMenu(
                profile: profile,
                onProfileTap: () {
                  Navigator.of(context).pop();
                  _navigateToProfile(context);
                },
                onSettingsTap: () {
                  Navigator.of(context).pop();
                  onSettingsTap?.call();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToProfile(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (context) => const ProfilePage()));
  }

  UserProfile _createFallbackProfile(String sleeperUserId) {
    return UserProfile(
      sleeperUserId: sleeperUserId,
      sleeperUsername: 'th0rjc', // Default for testing
      displayName: 'Thor (Test User)',
      createdAt: DateTime.now(),
    );
  }
}
