class League {
  final String id;
  final String sleeperLeagueId;
  final String? appUserId; // Made nullable since it's not always returned
  final String leagueName;
  final int season;
  final String sport;
  final String? leagueType;
  final int? totalRosters;
  final Map<String, dynamic>? scoringSettings;
  final Map<String, dynamic>? settings; // League settings (separate from scoring)
  final Map<String, dynamic>? metadata; // League metadata
  final List<String>? rosterPositions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSynced;
  final bool isActive;
  final String? avatar; // League avatar ID from Sleeper
  final String? status; // League status: pre_draft, drafting, in_season, complete

  const League({
    required this.id,
    required this.sleeperLeagueId,
    this.appUserId, // Made optional
    required this.leagueName,
    required this.season,
    required this.sport,
    this.leagueType,
    this.totalRosters,
    this.scoringSettings,
    this.settings,
    this.metadata,
    this.rosterPositions,
    required this.createdAt,
    required this.updatedAt,
    this.lastSynced,
    this.isActive = true,
    this.avatar,
    this.status,
  });

  factory League.fromJson(Map<String, dynamic> json) {
    return League(
      id: json['id'] as String? ?? '',
      sleeperLeagueId: json['sleeper_league_id'] as String? ?? '',
      appUserId: json['app_user_id'] as String?, // Made nullable
      leagueName: json['league_name'] as String? ?? 'Unknown League',
      season: json['season'] as int? ?? DateTime.now().year,
      sport: json['sport'] as String? ?? 'nfl',
      leagueType: json['league_type'] as String?,
      totalRosters: json['total_rosters'] as int?,
      scoringSettings: json['scoring_settings'] as Map<String, dynamic>?,
      settings: json['settings'] as Map<String, dynamic>?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      rosterPositions: (json['roster_positions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      lastSynced: json['last_synced'] != null
          ? DateTime.parse(json['last_synced'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      avatar: json['avatar'] as String?,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sleeper_league_id': sleeperLeagueId,
      if (appUserId != null) 'app_user_id': appUserId,
      'league_name': leagueName,
      'season': season,
      'sport': sport,
      'league_type': leagueType,
      'total_rosters': totalRosters,
      'scoring_settings': scoringSettings,
      'settings': settings,
      'metadata': metadata,
      'roster_positions': rosterPositions,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_synced': lastSynced?.toIso8601String(),
      'is_active': isActive,
      'avatar': avatar,
      'status': status,
    };
  }
}

class LeagueListItem {
  final String id;
  final String leagueName;
  final int season;
  final String leagueType;
  final int totalRosters;
  final DateTime lastSynced;
  final bool isActive;

  const LeagueListItem({
    required this.id,
    required this.leagueName,
    required this.season,
    required this.leagueType,
    required this.totalRosters,
    required this.lastSynced,
    this.isActive = true,
  });

  factory LeagueListItem.fromLeague(League league) => LeagueListItem(
    id: league.id,
    leagueName: league.leagueName,
    season: league.season,
    leagueType: league.leagueType ?? 'redraft',
    totalRosters: league.totalRosters ?? 12,
    lastSynced: league.lastSynced ?? league.updatedAt,
    isActive: league.isActive,
  );
}
