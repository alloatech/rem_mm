import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/features/admin/presentation/providers/admin_providers.dart';

class AdminAuditLog extends ConsumerWidget {
  final String sleeperUserId;

  const AdminAuditLog({super.key, required this.sleeperUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditAsync = ref.watch(roleAuditProvider(sleeperUserId));

    return auditAsync.when(
      data: (auditEntries) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(roleAuditProvider(sleeperUserId));
          await ref.read(roleAuditProvider(sleeperUserId).future);
        },
        child: auditEntries.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No audit entries found'),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: auditEntries.length,
                itemBuilder: (context, index) {
                  final entry = auditEntries[index];
                  return _AuditEntryCard(entry: entry);
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
            Text('Error loading audit log: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(roleAuditProvider(sleeperUserId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditEntryCard extends StatelessWidget {
  final Map<String, dynamic> entry;

  const _AuditEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final targetUser = entry['target_user'];
    final changedByUser = entry['changed_by_user'];
    final createdAt = DateTime.parse(entry['created_at'] as String);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(entry['new_role'] as String),
          child: Icon(
            _getRoleIcon(entry['new_role'] as String),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          targetUser != null
              ? '${targetUser['sleeper_username']} role changed'
              : 'Role change',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_formatRole(entry['old_role'] as String)} → ${_formatRole(entry['new_role'] as String)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Changed by: ${changedByUser != null ? changedByUser['sleeper_username'] : 'Unknown'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (entry['reason'] != null) ...[
              const SizedBox(height: 2),
              Text(
                'Reason: ${entry['reason']}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatDate(createdAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            Text(
              _formatTime(createdAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'user':
        return Colors.blue;
      case 'admin':
        return Colors.orange;
      case 'super_admin':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'user':
        return Icons.person;
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      case 'super_admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.help_outline;
    }
  }

  String _formatRole(String role) {
    switch (role) {
      case 'user':
        return 'User';
      case 'admin':
        return 'Admin';
      case 'super_admin':
        return 'Super Admin';
      default:
        return role;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
