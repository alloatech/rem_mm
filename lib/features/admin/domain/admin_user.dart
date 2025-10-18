enum UserRole { user, admin, superAdmin }

extension UserRoleExtension on UserRole {
  String get jsonValue {
    switch (this) {
      case UserRole.user:
        return 'user';
      case UserRole.admin:
        return 'admin';
      case UserRole.superAdmin:
        return 'super_admin';
    }
  }

  static UserRole fromJson(String value) {
    switch (value) {
      case 'user':
        return UserRole.user;
      case 'admin':
        return UserRole.admin;
      case 'super_admin':
        return UserRole.superAdmin;
      default:
        return UserRole.user;
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.user:
        return 'User';
      case UserRole.admin:
        return 'Admin';
      case UserRole.superAdmin:
        return 'Super Admin';
    }
  }
}

class AdminUser {
  final String sleeperUserId;
  final String sleeperUsername;
  final String? displayName;
  final UserRole userRole;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final bool isActive;

  const AdminUser({
    required this.sleeperUserId,
    required this.sleeperUsername,
    this.displayName,
    required this.userRole,
    required this.createdAt,
    this.lastLogin,
    this.isActive = true,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      sleeperUserId: json['sleeper_user_id'] as String,
      sleeperUsername: json['sleeper_username'] as String,
      displayName: json['display_name'] as String?,
      userRole: UserRoleExtension.fromJson(json['user_role'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sleeper_user_id': sleeperUserId,
      'sleeper_username': sleeperUsername,
      'display_name': displayName,
      'user_role': userRole.jsonValue,
      'created_at': createdAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
      'is_active': isActive,
    };
  }
}

class AdminStatus {
  final bool isAdmin;
  final bool isSuperAdmin;
  final String userId;
  final UserRole userRole;

  const AdminStatus({
    required this.isAdmin,
    required this.isSuperAdmin,
    required this.userId,
    required this.userRole,
  });

  factory AdminStatus.fromJson(Map<String, dynamic> json) {
    return AdminStatus(
      isAdmin: json['is_admin'] as bool,
      isSuperAdmin: json['is_super_admin'] as bool,
      userId: json['user_id'] as String,
      userRole: UserRoleExtension.fromJson(json['user_role'] as String),
    );
  }
}

class RoleChangeRequest {
  final String targetUserId;
  final UserRole newRole;
  final String? reason;

  const RoleChangeRequest({
    required this.targetUserId,
    required this.newRole,
    this.reason,
  });

  Map<String, dynamic> toJson() {
    return {
      'target_user_id': targetUserId,
      'new_role': newRole.jsonValue,
      'reason': reason,
    };
  }
}
