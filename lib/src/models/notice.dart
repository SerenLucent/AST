class Notice {
  const Notice({
    required this.id,
    required this.title,
    required this.memo,
    required this.createdAt,
    required this.authorId,
    required this.authorNickname,
  });

  final String id;
  final String title;
  final String memo;
  final DateTime createdAt;
  final String authorId;
  final String authorNickname;

  factory Notice.fromJson(Map<String, dynamic> json) => Notice(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    memo: json['memo'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    authorId: json['authorId'] as String? ?? '',
    authorNickname: json['authorNickname'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'memo': memo,
    'createdAt': createdAt.toIso8601String(),
    'authorId': authorId,
    'authorNickname': authorNickname,
  };
}
