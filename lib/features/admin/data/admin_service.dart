import 'package:rem_mm/features/admin/domain/admin_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  final SupabaseClient _supabase;
  static const String _adminManagementFunction = 'admin-management';

  AdminService(this._supabase);

  /// Check if current user has admin privileges
  Future<AdminStatus> checkAdminStatus(String sleeperUserId) async {
    try {
      final response = await _supabase.functions.invoke(
        _adminManagementFunction,
        body: {'action': 'check_admin_status', 'sleeper_user_id': sleeperUserId},
      );

      if (response.data == null) {
        throw Exception('No response data received');
      }

      if (response.data['success'] != true) {
        throw Exception(response.data['error'] ?? 'Failed to check admin status');
      }

      return AdminStatus.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to check admin status: $e');
    }
  }

  /// Get list of all users (admin only)
  Future<List<AdminUser>> getAllUsers(String sleeperUserId) async {
    try {
      final response = await _supabase.functions.invoke(
        _adminManagementFunction,
        body: {'action': 'list_users', 'sleeper_user_id': sleeperUserId},
      );

      if (response.data == null) {
        throw Exception('No response data received');
      }

      if (response.data['success'] != true) {
        throw Exception(response.data['error'] ?? 'Failed to get users');
      }

      final users = response.data['users'];
      if (users == null) {
        throw Exception('No users data in response');
      }

      return (users as List)
          .map((user) => AdminUser.fromJson(user as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get users: $e');
    }
  }

  /// Change user role (admin only)
  Future<bool> changeUserRole(String adminUserId, RoleChangeRequest request) async {
    try {
      final response = await _supabase.functions.invoke(
        _adminManagementFunction,
        body: {
          'action': 'change_role',
          'sleeper_user_id': adminUserId,
          ...request.toJson(),
        },
      );

      if (response.data == null) {
        throw Exception('No response data received');
      }

      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Failed to change role');
      }

      return true;
    } catch (e) {
      throw Exception('Failed to change user role: $e');
    }
  }

  /// Get role change audit log (admin only)
  Future<List<Map<String, dynamic>>> getRoleAudit(String sleeperUserId) async {
    try {
      final response = await _supabase.functions.invoke(
        _adminManagementFunction,
        body: {'action': 'get_role_audit', 'sleeper_user_id': sleeperUserId},
      );

      if (response.data == null) {
        throw Exception('No response data received');
      }

      if (response.data['success'] != true) {
        throw Exception(response.data['error'] ?? 'Failed to get audit log');
      }

      final auditLog = response.data['audit_log'];
      if (auditLog == null) {
        return [];
      }

      return List<Map<String, dynamic>>.from(auditLog as Iterable);
    } catch (e) {
      throw Exception('Failed to get audit log: $e');
    }
  }
}
