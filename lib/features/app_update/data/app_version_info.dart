/// The version of this app the Console superadmin has made active.
///
/// Answered by `GET /api/v1/app/version` on tenancy-app: only an active,
/// published version, and only metadata - the binary lives at [downloadUrl].
class AppVersionInfo {
  const AppVersionInfo({
    required this.version,
    required this.buildNumber,
    required this.forceUpdate,
    required this.downloadUrl,
    this.releaseNotes,
  });

  final String version;
  final int buildNumber;
  final bool forceUpdate;
  final String downloadUrl;
  final String? releaseNotes;

  /// Null when the payload is not a usable version. A server answer that
  /// cannot be read is never treated as an instruction to update.
  static AppVersionInfo? fromJson(Map<String, dynamic> json) {
    final build = json['build_number'];
    final url = json['download_url'];
    final version = json['version'];

    if (build is! int || build < 1 || url is! String || url.isEmpty) {
      return null;
    }

    return AppVersionInfo(
      version: version is String ? version : '$build',
      buildNumber: build,
      forceUpdate: json['force_update'] == true,
      downloadUrl: url,
      releaseNotes: json['release_notes'] is String ? json['release_notes'] as String : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'build_number': buildNumber,
    'force_update': forceUpdate,
    'download_url': downloadUrl,
    'release_notes': releaseNotes,
  };
}

enum UpdateRequirement { none, optional, required }

/// Whether an installed build has to, may, or need not update.
///
/// Compared on the build number only; the version name is for people.
UpdateRequirement evaluateUpdate({
  required int installedBuild,
  required AppVersionInfo? latest,
}) {
  if (latest == null || installedBuild >= latest.buildNumber) {
    return UpdateRequirement.none;
  }

  return latest.forceUpdate ? UpdateRequirement.required : UpdateRequirement.optional;
}
