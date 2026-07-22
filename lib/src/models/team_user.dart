class TeamUser {
  const TeamUser({
    required this.loginId,
    required this.nickname,
    required this.registeredAt,
    required this.lastLoginAt,
    this.canUploadScores = false,
    this.canUploadHistory = false,
  });

  final String loginId;
  final String nickname;
  final DateTime registeredAt;
  final DateTime lastLoginAt;
  final bool canUploadScores;
  final bool canUploadHistory;

  factory TeamUser.fromJson(Map<String, dynamic> json) => TeamUser(
    loginId: json['loginId'] as String,
    nickname: json['nickname'] as String? ?? '',
    registeredAt: DateTime.parse(json['registeredAt'] as String).toLocal(),
    lastLoginAt: DateTime.parse(json['lastLoginAt'] as String).toLocal(),
    canUploadScores: json['canUploadScores'] as bool? ?? false,
    canUploadHistory: json['canUploadHistory'] as bool? ?? false,
  );

  TeamUser copyWith({
    String? nickname,
    DateTime? lastLoginAt,
    bool? canUploadScores,
    bool? canUploadHistory,
  }) => TeamUser(
    loginId: loginId,
    nickname: nickname ?? this.nickname,
    registeredAt: registeredAt,
    lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    canUploadScores: canUploadScores ?? this.canUploadScores,
    canUploadHistory: canUploadHistory ?? this.canUploadHistory,
  );

  Map<String, dynamic> toJson() => {
    'loginId': loginId,
    'nickname': nickname,
    'registeredAt': registeredAt.toUtc().toIso8601String(),
    'lastLoginAt': lastLoginAt.toUtc().toIso8601String(),
    'canUploadScores': canUploadScores,
    'canUploadHistory': canUploadHistory,
  };
}
