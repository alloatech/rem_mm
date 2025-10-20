import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/features/admin/domain/admin_user.dart';
import 'package:rem_mm/features/admin/presentation/providers/admin_providers.dart';
import 'package:rem_mm/features/admin/presentation/widgets/admin_audit_log.dart';
import 'package:rem_mm/features/admin/presentation/widgets/admin_users_list.dart';
import 'package:rem_mm/features/auth/presentation/providers/auth_providers.dart';

class AdminTab extends ConsumerWidget {
  const AdminTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sleeperUserIdAsync = ref.watch(currentSleeperUserIdProvider);

    return sleeperUserIdAsync.when(
      data: (sleeperUserId) {
        if (sleeperUserId == null) {
          return const Center(child: Text('No user logged in'));
        }

        final adminStatusAsync = ref.watch(adminStatusProvider(sleeperUserId));

        return adminStatusAsync.when(
          data: (AdminStatus adminStatus) {
            if (!adminStatus.isAdmin) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'Admin Access Required',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You do not have admin privileges to view this page.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Admin Panel',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Chip(
                                    label: Text(
                                      adminStatus.isSuperAdmin ? 'Super Admin' : 'Admin',
                                    ),
                                    backgroundColor: adminStatus.isSuperAdmin
                                        ? Colors.orange.shade100
                                        : Colors.blue.shade100,
                                  ),
                                  const SizedBox(width: 8),
                                  Chip(
                                    label: Text(adminStatus.userRole.displayName),
                                    backgroundColor: adminStatus.isSuperAdmin
                                        ? Colors.orange.shade100
                                        : Colors.green.shade100,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        TabBar(
                          tabs: const [
                            Tab(icon: Icon(Icons.people), text: 'Users'),
                            Tab(icon: Icon(Icons.history), text: 'Audit Log'),
                          ],
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
          loading: () => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Checking admin status...',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 8),
                Text(
                  'You do not have admin privileges to view this page.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                Text(
                  error.toString(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
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
      },
      loading: () => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading user data...'),
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
              'Error loading user data',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(currentSleeperUserIdProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
