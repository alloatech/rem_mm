import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/core/widgets/sleeper_avatar.dart';
import 'package:rem_mm/features/auth/presentation/pages/sleeper_link_page.dart';
import 'package:rem_mm/features/profile/domain/user_profile.dart';
import 'package:rem_mm/features/profile/presentation/providers/profile_providers.dart';

class ProfileMenu extends ConsumerWidget {
  final UserProfile? profile;
  final VoidCallback? onProfileTap;
  final VoidCallback? onSettingsTap;

  const ProfileMenu({super.key, this.profile, this.onProfileTap, this.onSettingsTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 8,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            if (profile != null) ...[
              Row(
                children: [
                  SleeperAvatar(
                    avatarId: profile!.avatarId,
                    fallbackText: profile!.displayName ?? profile!.sleeperUsername,
                    radius: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile!.displayName ?? profile!.sleeperUsername,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '@${profile!.sleeperUsername}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                            fontSize: 10,
                          ),
                        ),
                        if (profile!.status != UserStatus.active) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                profile!.status,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _getStatusColor(profile!.status)),
                            ),
                            child: Text(
                              profile!.status.displayName,
                              style: TextStyle(
                                fontSize: 10,
                                color: _getStatusColor(profile!.status),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
            ],

            // Menu Items
            _MenuTile(
              icon: Icons.person_outline,
              title: 'view profile',
              onTap: onProfileTap,
            ),
            _MenuTile(icon: Icons.settings, title: 'settings', onTap: onSettingsTap),
            _MenuTile(
              icon: Icons.link,
              title: 're-link sleeper account',
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => const SleeperLinkPage()));
              },
            ),
            _MenuTile(
              icon: Icons.help_outline,
              title: 'help & support',
              onTap: () {
                // TODO: Implement help/support
              },
            ),
            const Divider(),
            _MenuTile(
              icon: Icons.logout,
              title: 'sign out',
              onTap: () => _handleSignOut(context, ref),
              textColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.active:
        return Colors.green;
      case UserStatus.inactive:
        return Colors.orange;
      case UserStatus.suspended:
        return Colors.red;
    }
  }

  void _handleSignOut(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(signOutProvider.future);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Signed out successfully')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to sign out: $e')));
      }
    }
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Color? textColor;

  const _MenuTile({required this.icon, required this.title, this.onTap, this.textColor});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: textColor, size: 18),
      title: Text(
        title,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 12),
      ),
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
    );
  }
}
