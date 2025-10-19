import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/features/admin/data/admin_service.dart';
import 'package:rem_mm/features/admin/domain/admin_user.dart';
import 'package:rem_mm/features/auth/presentation/providers/auth_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Service provider
final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService(Supabase.instance.client);
});

// Current user's admin status
final adminStatusProvider = FutureProvider.family<AdminStatus, String>((
  ref,
  sleeperUserId,
) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.checkAdminStatus(sleeperUserId);
});

// All users list (admin only)
final allUsersProvider = FutureProvider.family<List<AdminUser>, String>((
  ref,
  sleeperUserId,
) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getAllUsers(sleeperUserId);
});

// Role audit log (admin only)
final roleAuditProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((
  ref,
  sleeperUserId,
) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getRoleAudit(sleeperUserId);
});

// Helper provider to check if current user is admin
final isCurrentUserAdminProvider = FutureProvider<bool>((ref) async {
  final sleeperUserId = await ref.watch(currentSleeperUserIdProvider.future);
  if (sleeperUserId == null) return false;

  try {
    // Add timeout to prevent infinite loading
    final status = await Future.any([
      ref.watch(adminStatusProvider(sleeperUserId).future),
      Future.delayed(
        const Duration(seconds: 10),
        () => throw TimeoutException('Admin check timeout', const Duration(seconds: 10)),
      ),
    ]);
    return status.isAdmin;
  } catch (e) {
    // If admin check fails, default to false (not admin)
    print('Admin status check failed: $e');
    return false;
  }
});

// Helper provider to check if current user is super admin
final isCurrentUserSuperAdminProvider = FutureProvider<bool>((ref) async {
  final sleeperUserId = await ref.watch(currentSleeperUserIdProvider.future);
  if (sleeperUserId == null) return false;

  try {
    final status = await ref.watch(adminStatusProvider(sleeperUserId).future);
    return status.isSuperAdmin;
  } catch (e) {
    return false;
  }
});
