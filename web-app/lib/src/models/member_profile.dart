class MemberProfile {
  const MemberProfile({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.memo,
  });

  final String id;
  final String name;
  final String imageUrl;
  final String memo;

  factory MemberProfile.fromJson(Map<String, dynamic> json) => MemberProfile(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    imageUrl: json['imageUrl'] as String? ?? '',
    memo: json['memo'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'imageUrl': imageUrl,
    'memo': memo,
  };
}
