class Player {
  final String playerId;
  final String? fullName;
  final String? firstName;
  final String? lastName;
  final String? position;
  final String? team;
  final String? teamAbbr;
  final String? status;
  final bool active;
  final String? depthChartPosition;
  final int? depthChartOrder;
  final String? injuryStatus;
  final String? injuryNotes;
  final String? injuryBodyPart;
  final DateTime? injuryStartDate;
  final String? practiceParticipation;
  final String? practiceDescription;
  final int? age;
  final String? height;
  final String? weight;
  final String? college;
  final int? yearsExp;
  final int? number;
  final String? rookieYear;

  const Player({
    required this.playerId,
    this.fullName,
    this.firstName,
    this.lastName,
    this.position,
    this.team,
    this.teamAbbr,
    this.status,
    this.active = true,
    this.depthChartPosition,
    this.depthChartOrder,
    this.injuryStatus,
    this.injuryNotes,
    this.injuryBodyPart,
    this.injuryStartDate,
    this.practiceParticipation,
    this.practiceDescription,
    this.age,
    this.height,
    this.weight,
    this.college,
    this.yearsExp,
    this.number,
    this.rookieYear,
  });

  /// Display name - for DEF/ST shows "City Mascot" (e.g., "Buffalo Bills")
  String get displayName {
    if (fullName != null && fullName!.isNotEmpty) {
      return fullName!;
    }
    // For DEF/ST teams, Sleeper provides first_name=city, last_name=mascot
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    if (firstName != null) return firstName!;
    if (lastName != null) return lastName!;
    return playerId; // Fallback to player ID
  }

  String get positionTeam {
    final pos = position ?? 'N/A';
    final tm = teamAbbr ?? team ?? '';
    return tm.isEmpty ? pos : '$pos, $tm';
  }

  bool get isInjured => injuryStatus != null && injuryStatus!.isNotEmpty;

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      playerId: json['player_id'] as String,
      fullName: json['full_name'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      position: json['position'] as String?,
      team: json['team'] as String?,
      teamAbbr: json['team_abbr'] as String?,
      status: json['status'] as String?,
      active: json['active'] as bool? ?? true,
      depthChartPosition: json['depth_chart_position'] as String?,
      depthChartOrder: json['depth_chart_order'] as int?,
      injuryStatus: json['injury_status'] as String?,
      injuryNotes: json['injury_notes'] as String?,
      injuryBodyPart: json['injury_body_part'] as String?,
      injuryStartDate: json['injury_start_date'] != null
          ? DateTime.parse(json['injury_start_date'] as String)
          : null,
      practiceParticipation: json['practice_participation'] as String?,
      practiceDescription: json['practice_description'] as String?,
      age: json['age'] as int?,
      height: json['height'] as String?,
      weight: json['weight'] as String?,
      college: json['college'] as String?,
      yearsExp: json['years_exp'] as int?,
      number: json['number'] as int?,
      rookieYear: json['rookie_year'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'player_id': playerId,
      'full_name': fullName,
      'first_name': firstName,
      'last_name': lastName,
      'position': position,
      'team': team,
      'team_abbr': teamAbbr,
      'status': status,
      'active': active,
      'depth_chart_position': depthChartPosition,
      'depth_chart_order': depthChartOrder,
      'injury_status': injuryStatus,
      'injury_notes': injuryNotes,
      'injury_body_part': injuryBodyPart,
      'injury_start_date': injuryStartDate?.toIso8601String(),
      'practice_participation': practiceParticipation,
      'practice_description': practiceDescription,
      'age': age,
      'height': height,
      'weight': weight,
      'college': college,
      'years_exp': yearsExp,
      'number': number,
      'rookie_year': rookieYear,
    };
  }
}
