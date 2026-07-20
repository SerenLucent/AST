class ScheduleEntry {
  const ScheduleEntry({
    required this.id,
    required this.scheduledAt,
    required this.memo,
    required this.authorId,
    required this.authorNickname,
  });

  final String id;
  final DateTime scheduledAt;
  final String memo;
  final String authorId;
  final String authorNickname;

  factory ScheduleEntry.fromJson(Map<String, dynamic> json) => ScheduleEntry(
    id: json['id'] as String,
    scheduledAt: DateTime.parse(json['scheduledAt'] as String).toLocal(),
    memo: json['memo'] as String? ?? '',
    authorId: json['authorId'] as String? ?? '',
    authorNickname: json['authorNickname'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'scheduledAt': scheduledAt.toIso8601String(),
    'memo': memo,
    'authorId': authorId,
    'authorNickname': authorNickname,
  };
}
