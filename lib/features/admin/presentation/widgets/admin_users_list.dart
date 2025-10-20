import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/features/admin/domain/admin_user.dart';
import 'package:rem_mm/features/admin/presentation/providers/admin_providers.dart';

class AdminUsersList extends ConsumerWidget {
  final String sleeperUserId;
  final bool isSuperAdmin;

  const AdminUsersList({
    super.key,
    required this.sleeperUserId,
    required this.isSuperAdmin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider(sleeperUserId));

    return usersAsync.when(
      data: (users) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allUsersProvider(sleeperUserId));
          await ref.read(allUsersProvider(sleeperUserId).future);
        },
        child: users.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No users found'),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return _UserCard(
                    user: user,
                    isSuperAdmin: isSuperAdmin,
                    currentSleeperUserId: sleeperUserId,
                    onRoleChanged: () {
                      ref.invalidate(allUsersProvider(sleeperUserId));
                    },
                  );
                },
              ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text('Error loading users: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(allUsersProvider(sleeperUserId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends ConsumerWidget {
  final AdminUser user;
  final bool isSuperAdmin;
  final String currentSleeperUserId;
  final VoidCallback onRoleChanged;

  const _UserCard({
    required this.user,
    required this.isSuperAdmin,
    required this.currentSleeperUserId,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(user.userRole),
          child: Text(
            user.sleeperUsername.substring(0, 1).toUpperCase(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          user.displayName ?? user.sleeperUsername,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('@${user.sleeperUsername}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(
                    user.userRole.displayName,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 12),
                  ),
                  backgroundColor: _getRoleColor(user.userRole).withValues(alpha: 0.1),
                  side: BorderSide(color: _getRoleColor(user.userRole)),
                ),
                if (!user.isActive) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      'Inactive',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(fontSize: 12),
                    ),
                    backgroundColor: Colors.grey,
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: isSuperAdmin && user.sleeperUserId != currentSleeperUserId
            ? PopupMenuButton<UserRole>(
                icon: const Icon(Icons.more_vert),
                onSelected: (newRole) => _changeUserRole(context, ref, user, newRole),
                itemBuilder: (context) => UserRole.values
                    .where((role) => role != user.userRole)
                    .map(
                      (role) => PopupMenuItem(
                        value: role,
                        child: Row(
                          children: [
                            Icon(
                              _getRoleIcon(role),
                              color: _getRoleColor(role),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text('Make ${role.displayName}'),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              )
            : null,
        isThreeLine: true,
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.user:
        return Colors.blue;
      case UserRole.admin:
        return Colors.orange;
      case UserRole.superAdmin:
        return Colors.red;
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.user:
        return Icons.person;
      case UserRole.admin:
        return Icons.admin_panel_settings_outlined;
      case UserRole.superAdmin:
        return Icons.admin_panel_settings;
    }
  }

  Future<void> _changeUserRole(
    BuildContext context,
    WidgetRef ref,
    AdminUser user,
    UserRole newRole,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change User Role'),
        content: Text(
          'Are you sure you want to change ${user.sleeperUsername}\'s role from '
          '${user.userRole.displayName} to ${newRole.displayName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Change Role'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final adminService = ref.read(adminServiceProvider);

      await adminService.changeUserRole(
        currentSleeperUserId,
        RoleChangeRequest(
          targetUserId: user.sleeperUserId,
          newRole: newRole,
          reason: 'Changed via admin panel',
        ),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully changed ${user.sleeperUsername}\'s role to ${newRole.displayName}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      onRoleChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
