class TeamUser {
  static const generationPriority = ['1기', '2기', '3기', '4기', 'Guest'];

  const TeamUser({
    required this.loginId,
    required this.nickname,
    required this.registeredAt,
    required this.lastLoginAt,
    this.memberId = '',
    this.canUploadScores = false,
    this.canUploadHistory = false,
    this.generations = const [],
  });

  final String loginId;
  final String memberId;
  final String nickname;
  final DateTime registeredAt;
  final DateTime lastLoginAt;
  final bool canUploadScores;
  final bool canUploadHistory;
  final List<String> generations;

  String? get primaryGeneration {
    for (final generation in generationPriority) {
      if (generations.contains(generation)) {
        return generation;
      }
    }
    return generations.isEmpty ? null : generations.first;
  }

  static List<String> sortGenerations(Iterable<String> values) {
    final unique = values.toSet();
    return [...generationPriority.where(unique.remove), ...unique];
  }

  int generationRank(String selectedGeneration) {
    final displayOrder = [
      selectedGeneration,
      ...generationPriority.where((value) => value != selectedGeneration),
    ];
    for (var index = 0; index < displayOrder.length; index++) {
      if (generations.contains(displayOrder[index])) {
        return index;
      }
    }
    return displayOrder.length;
  }

  factory TeamUser.fromJson(Map<String, dynamic> json) => TeamUser(
    loginId: json['loginId'] as String,
    memberId: json['memberId'] as String? ?? '',
    nickname: json['nickname'] as String? ?? '',
    registeredAt: DateTime.parse(json['registeredAt'] as String).toLocal(),
    lastLoginAt: DateTime.parse(json['lastLoginAt'] as String).toLocal(),
    canUploadScores: json['canUploadScores'] as bool? ?? false,
    canUploadHistory: json['canUploadHistory'] as bool? ?? false,
    generations: sortGenerations(
      (json['generations'] as List<dynamic>? ?? const []).whereType<String>(),
    ),
  );

  TeamUser copyWith({
    String? memberId,
    String? nickname,
    DateTime? lastLoginAt,
    bool? canUploadScores,
    bool? canUploadHistory,
    List<String>? generations,
  }) => TeamUser(
    loginId: loginId,
    memberId: memberId ?? this.memberId,
    nickname: nickname ?? this.nickname,
    registeredAt: registeredAt,
    lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    canUploadScores: canUploadScores ?? this.canUploadScores,
    canUploadHistory: canUploadHistory ?? this.canUploadHistory,
    generations: sortGenerations(generations ?? this.generations),
  );

  Map<String, dynamic> toJson() => {
    'loginId': loginId,
    'memberId': memberId,
    'nickname': nickname,
    'registeredAt': registeredAt.toUtc().toIso8601String(),
    'lastLoginAt': lastLoginAt.toUtc().toIso8601String(),
    'canUploadScores': canUploadScores,
    'canUploadHistory': canUploadHistory,
  };
}

int compareTeamUsersByGeneration(
  TeamUser? a,
  TeamUser? b,
  String selectedGeneration,
) {
  final aGenerations =
      a?.generations.where((value) => value != 'Guest').toList() ?? const [];
  final bGenerations =
      b?.generations.where((value) => value != 'Guest').toList() ?? const [];
  final selectedComparison = (bGenerations.contains(selectedGeneration) ? 1 : 0)
      .compareTo(aGenerations.contains(selectedGeneration) ? 1 : 0);
  if (selectedComparison != 0) return selectedComparison;
  return bGenerations.length.compareTo(aGenerations.length);
}
