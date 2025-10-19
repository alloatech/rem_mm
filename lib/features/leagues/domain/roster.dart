class Roster {
  final String id;
  final String? appUserId; // NULL if owner not registered
  final String leagueId;
  final String sleeperOwnerId; // Always present - use for avatar URL
  final int sleeperRosterId;
  final String? teamName; // e.g., "GlenSuckIt Rangers"
  final String? ownerDisplayName; // e.g., "th0rJC"
  final String? avatarId; // Sleeper avatar ID for CDN URLs
  final String? teamAvatarUrl; // Team-specific avatar URL (preferred for rosters)
  final List<String> playerIds;
  final List<String> starters;
  final List<String> reserves;
  final List<String> taxi;
  final Map<String, dynamic>? settings;
  final DateTime? lastSynced;
  final bool isCurrentUser; // Computed: matches logged-in user

  const Roster({
    required this.id,
    this.appUserId,
    required this.leagueId,
    required this.sleeperOwnerId,
    required this.sleeperRosterId,
    this.teamName,
    this.ownerDisplayName,
    this.avatarId,
    this.teamAvatarUrl,
    required this.playerIds,
    required this.starters,
    required this.reserves,
    required this.taxi,
    this.settings,
    this.lastSynced,
    this.isCurrentUser = false,
  });

  /// Get avatar URL - prefer team avatar, fallback to user avatar
  String? get avatarUrl {
    // Prefer team-specific avatar if available
    if (teamAvatarUrl != null && teamAvatarUrl!.isNotEmpty) {
      return teamAvatarUrl;
    }
    // Fallback to user avatar constructed from avatar_id
    return avatarId != null ? 'https://sleepercdn.com/avatars/thumbs/$avatarId' : null;
  }

  /// Display name for the roster
  String get displayName {
    if (teamName != null && teamName!.isNotEmpty) {
      return '$teamName [$ownerDisplayName]';
    }
    return ownerDisplayName ?? 'Team $sleeperRosterId';
  }

  /// Short team name (just the custom name or owner name)
  String get shortName => teamName ?? ownerDisplayName ?? 'Team $sleeperRosterId';

  /// Season stats from settings
  int get wins => settings?['wins'] as int? ?? 0;
  int get losses => settings?['losses'] as int? ?? 0;
  int get ties => settings?['ties'] as int? ?? 0;

  double get pointsFor {
    final fpts = settings?['fpts'] as int? ?? 0;
    final decimal = settings?['fpts_decimal'] as int? ?? 0;
    return fpts + (decimal / 100);
  }

  double get pointsAgainst {
    final fpts = settings?['fpts_against'] as int? ?? 0;
    final decimal = settings?['fpts_against_decimal'] as int? ?? 0;
    return fpts + (decimal / 100);
  }

  String get record => '$wins-$losses${ties > 0 ? '-$ties' : ''}';

  factory Roster.fromJson(Map<String, dynamic> json, {String? currentUserSleeperID}) {
    final sleeperOwnerId = json['sleeper_owner_id'] as String;
    final isCurrentUser =
        currentUserSleeperID != null && sleeperOwnerId == currentUserSleeperID;

    return Roster(
      id: json['id'] as String,
      appUserId: json['app_user_id'] as String?,
      leagueId: json['league_id'] as String,
      sleeperOwnerId: sleeperOwnerId,
      sleeperRosterId: json['sleeper_roster_id'] as int,
      teamName: json['team_name'] as String?,
      ownerDisplayName: json['owner_display_name'] as String?,
      avatarId: json['avatar_id'] as String?,
      teamAvatarUrl: json['team_avatar_url'] as String?,
      playerIds: (json['player_ids'] as List<dynamic>).map((e) => e as String).toList(),
      starters: (json['starters'] as List<dynamic>).map((e) => e as String).toList(),
      reserves: (json['reserves'] as List<dynamic>).map((e) => e as String).toList(),
      taxi: (json['taxi'] as List<dynamic>).map((e) => e as String).toList(),
      settings: json['settings'] as Map<String, dynamic>?,
      lastSynced: json['last_synced'] != null
          ? DateTime.parse(json['last_synced'] as String)
          : null,
      isCurrentUser: isCurrentUser,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'app_user_id': appUserId,
      'league_id': leagueId,
      'sleeper_owner_id': sleeperOwnerId,
      'sleeper_roster_id': sleeperRosterId,
      'team_name': teamName,
      'owner_display_name': ownerDisplayName,
      'avatar_id': avatarId,
      'team_avatar_url': teamAvatarUrl,
      'player_ids': playerIds,
      'starters': starters,
      'reserves': reserves,
      'taxi': taxi,
      'settings': settings,
      'last_synced': lastSynced?.toIso8601String(),
    };
  }

  Roster copyWith({
    String? id,
    String? appUserId,
    String? leagueId,
    String? sleeperOwnerId,
    int? sleeperRosterId,
    String? teamName,
    String? ownerDisplayName,
    List<String>? playerIds,
    List<String>? starters,
    List<String>? reserves,
    List<String>? taxi,
    Map<String, dynamic>? settings,
    DateTime? lastSynced,
    bool? isCurrentUser,
  }) {
    return Roster(
      id: id ?? this.id,
      appUserId: appUserId ?? this.appUserId,
      leagueId: leagueId ?? this.leagueId,
      sleeperOwnerId: sleeperOwnerId ?? this.sleeperOwnerId,
      sleeperRosterId: sleeperRosterId ?? this.sleeperRosterId,
      teamName: teamName ?? this.teamName,
      ownerDisplayName: ownerDisplayName ?? this.ownerDisplayName,
      playerIds: playerIds ?? this.playerIds,
      starters: starters ?? this.starters,
      reserves: reserves ?? this.reserves,
      taxi: taxi ?? this.taxi,
      settings: settings ?? this.settings,
      lastSynced: lastSynced ?? this.lastSynced,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }
}
