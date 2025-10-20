import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/features/auth/presentation/providers/auth_providers.dart';
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
    final sleeperUserIdAsync = ref.watch(currentSleeperUserIdProvider);

    return sleeperUserIdAsync.when(
      data: (sleeperUserId) {
        if (sleeperUserId == null) {
          return CircleAvatar(radius: size / 2, child: const Icon(Icons.person));
        }

        final profileAsync = ref.watch(currentUserProfileProvider(sleeperUserId));

        return profileAsync.when(
          data: (profile) {
            // Always use user's personal avatar, never team avatar
            final userAvatarUrl = profile?.avatarId != null
                ? 'https://sleepercdn.com/avatars/thumbs/${profile!.avatarId}'
                : null;

            return GestureDetector(
              onTap: () => _showProfileMenu(context, profile),
              child: CircleAvatar(
                radius: size / 2,
                backgroundColor: Colors.white, // Changed from orange to white
                backgroundImage: userAvatarUrl != null
                    ? NetworkImage(userAvatarUrl)
                    : null,
                child: userAvatarUrl == null
                    ? Text(
                        profile?.sleeperUsername.substring(0, 1).toUpperCase() ?? 'U',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: size * 0.4,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : null,
              ),
            );
          },
          loading: () => CircleAvatar(
            radius: size / 2,
            child: SizedBox(
              width: size * 0.6,
              height: size * 0.6,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (error, stack) => GestureDetector(
            onTap: () => _showProfileMenu(context, null),
            child: CircleAvatar(
              radius: size / 2,
              backgroundColor: Colors.grey.shade300,
              child: Icon(Icons.error_outline, size: size * 0.5, color: Colors.red),
            ),
          ),
        );
      },
      loading: () => CircleAvatar(
        radius: size / 2,
        child: SizedBox(
          width: size * 0.6,
          height: size * 0.6,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, stack) => GestureDetector(
        onTap: () => _showProfileMenu(context, null),
        child: CircleAvatar(
          radius: size / 2,
          backgroundColor: Colors.grey.shade300,
          child: Icon(Icons.error_outline, size: size * 0.5, color: Colors.red),
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
}
