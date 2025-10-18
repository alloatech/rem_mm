import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/features/admin/domain/admin_user.dart';
import 'package:rem_mm/features/admin/presentation/providers/admin_providers.dart';
import 'package:rem_mm/features/admin/presentation/widgets/admin_audit_log.dart';
import 'package:rem_mm/features/admin/presentation/widgets/admin_users_list.dart';
import 'package:rem_mm/features/profile/presentation/providers/profile_providers.dart';

class AdminTab extends ConsumerWidget {
  const AdminTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sleeperUserId = ref.watch(currentSleeperUserIdProvider);

    if (sleeperUserId == null) {
      return const Center(child: Text('No user logged in'));
    }

    final adminStatusAsync = ref.watch(adminStatusProvider(sleeperUserId));

    return adminStatusAsync.when(
      data: (AdminStatus adminStatus) {
        if (!adminStatus.isAdmin) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Admin Access Required',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'You do not have admin privileges to view this page.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Container(
                color: Theme.of(context).colorScheme.surface,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings,
                            color: Theme.of(context).colorScheme.primary,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Admin Panel',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              Text(
                                adminStatus.isSuperAdmin ? 'Super Admin' : 'Admin',
                                style: TextStyle(
                                  color: adminStatus.isSuperAdmin
                                      ? Colors.red
                                      : Theme.of(context).colorScheme.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Chip(
                            label: Text(adminStatus.userRole.displayName),
                            backgroundColor: adminStatus.isSuperAdmin
                                ? Colors.red.shade50
                                : Theme.of(context).colorScheme.secondaryContainer,
                          ),
                        ],
                      ),
                    ),
                    TabBar(
                      tabs: const [
                        Tab(icon: Icon(Icons.people), text: 'Users'),
                        Tab(icon: Icon(Icons.history), text: 'Audit Log'),
                      ],
                      labelColor: Theme.of(context).colorScheme.primary,
                      unselectedLabelColor: Colors.grey,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    AdminUsersList(
                      sleeperUserId: sleeperUserId,
                      isSuperAdmin: adminStatus.isSuperAdmin,
                    ),
                    AdminAuditLog(sleeperUserId: sleeperUserId),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Checking admin status...'),
          ],
        ),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Error checking admin status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(adminStatusProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
