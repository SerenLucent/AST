class HistoryFile {
  const HistoryFile({
    required this.name,
    required this.path,
    required this.sha,
    required this.downloadUrl,
    required this.size,
  });

  final String name;
  final String path;
  final String sha;
  final String downloadUrl;
  final int size;

  factory HistoryFile.fromJson(Map<String, dynamic> json) => HistoryFile(
    name: json['name'] as String,
    path: json['path'] as String,
    sha: json['sha'] as String,
    downloadUrl: json['download_url'] as String,
    size: json['size'] as int? ?? 0,
  );

  String get extension =>
      name.contains('.') ? name.split('.').last.toLowerCase() : '';

  String get displayName =>
      extension.isEmpty
          ? name
          : name.substring(0, name.length - extension.length - 1);

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get mimeType => switch (extension) {
    'pdf' => 'application/pdf',
    'ppt' => 'application/vnd.ms-powerpoint',
    'pptx' =>
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    _ => 'application/octet-stream',
  };
}
