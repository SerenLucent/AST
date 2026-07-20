class ScoreFile {
  const ScoreFile({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });

  final String name;
  final String downloadUrl;
  final int size;

  factory ScoreFile.fromJson(Map<String, dynamic> json) => ScoreFile(
    name: json['name'] as String,
    downloadUrl: json['download_url'] as String,
    size: json['size'] as int? ?? 0,
  );

  String get displayName =>
      name.toLowerCase().endsWith('.pdf')
          ? name.substring(0, name.length - 4)
          : name;

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
