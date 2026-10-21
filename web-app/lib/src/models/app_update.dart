class AppUpdate {
  const AppUpdate({
    required this.versionName,
    required this.apkFile,
    required this.apkUrl,
    required this.message,
    required this.requiredUpdate,
  });
  final String versionName, apkFile, apkUrl, message;
  final bool requiredUpdate;
  factory AppUpdate.fromJson(Map<String, dynamic> json) => AppUpdate(
    versionName: json['versionName']?.toString() ?? '',
    apkFile: json['apkFile']?.toString() ?? '',
    apkUrl: json['apkUrl']?.toString() ?? '',
    message: json['message']?.toString() ?? '',
    requiredUpdate: json['required'] == true,
  );
  bool isNewerThan(String current) {
    List<int> parts(String value) =>
        value.split('.').map((v) => int.tryParse(v) ?? 0).toList();
    final remote = parts(versionName), local = parts(current);
    for (var i = 0; i < 3; i++) {
      final comparison = (i < remote.length ? remote[i] : 0).compareTo(
        i < local.length ? local[i] : 0,
      );
      if (comparison != 0) return comparison > 0;
    }
    return false;
  }
}
