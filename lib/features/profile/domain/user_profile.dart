enum UserStatus { active, inactive, suspended }

extension UserStatusExtension on UserStatus {
  String get jsonValue {
    switch (this) {
      case UserStatus.active:
        return 'active';
      case UserStatus.inactive:
        return 'inactive';
      case UserStatus.suspended:
        return 'suspended';
    }
  }

  static UserStatus fromJson(String value) {
    switch (value) {
      case 'active':
        return UserStatus.active;
      case 'inactive':
        return UserStatus.inactive;
      case 'suspended':
        return UserStatus.suspended;
      default:
        return UserStatus.active;
    }
  }

  String get displayName {
    switch (this) {
      case UserStatus.active:
        return 'Active';
      case UserStatus.inactive:
        return 'Inactive';
      case UserStatus.suspended:
        return 'Suspended';
    }
  }
}

class UserProfile {
  final String sleeperUserId;
  final String sleeperUsername;
  final String? displayName;
  final String? email;
  final String? avatarUrl;
  final UserStatus status;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final Map<String, dynamic>? preferences;

  const UserProfile({
    required this.sleeperUserId,
    required this.sleeperUsername,
    this.displayName,
    this.email,
    this.avatarUrl,
    this.status = UserStatus.active,
    required this.createdAt,
    this.lastLogin,
    this.preferences,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      sleeperUserId: json['sleeper_user_id'] as String,
      sleeperUsername: json['sleeper_username'] as String,
      displayName: json['display_name'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      status: UserStatusExtension.fromJson(json['status'] as String? ?? 'active'),
      createdAt: DateTime.parse(json['created_at'] as String),
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'] as String)
          : null,
      preferences: json['preferences'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sleeper_user_id': sleeperUserId,
      'sleeper_username': sleeperUsername,
      'display_name': displayName,
      'email': email,
      'avatar_url': avatarUrl,
      'status': status.jsonValue,
      'created_at': createdAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
      'preferences': preferences,
    };
  }

  UserProfile copyWith({
    String? sleeperUserId,
    String? sleeperUsername,
    String? displayName,
    String? email,
    String? avatarUrl,
    UserStatus? status,
    DateTime? createdAt,
    DateTime? lastLogin,
    Map<String, dynamic>? preferences,
  }) {
    return UserProfile(
      sleeperUserId: sleeperUserId ?? this.sleeperUserId,
      sleeperUsername: sleeperUsername ?? this.sleeperUsername,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      preferences: preferences ?? this.preferences,
    );
  }
}

class ProfileUpdateRequest {
  final String? displayName;
  final String? email;
  final String? avatarUrl;
  final Map<String, dynamic>? preferences;

  const ProfileUpdateRequest({
    this.displayName,
    this.email,
    this.avatarUrl,
    this.preferences,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {};
    if (displayName != null) json['display_name'] = displayName;
    if (email != null) json['email'] = email;
    if (avatarUrl != null) json['avatar_url'] = avatarUrl;
    if (preferences != null) json['preferences'] = preferences;
    return json;
  }
}
