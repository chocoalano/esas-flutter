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
    this.replacement,
  });

  final String version;
  final int buildNumber;
  final bool forceUpdate;
  final String downloadUrl;
  final String? releaseNotes;

  /// Set when the app has moved to a different application package. Never
  /// read as an update of this app; see [AppReplacement].
  final AppReplacement? replacement;

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
      releaseNotes: json['release_notes'] is String
          ? json['release_notes'] as String
          : null,
      replacement: AppReplacement.fromJson(json['replacement']),
    );
  }

  /// Whether [downloadUrl] is an app store page, where the store installs the
  /// update. Anything else (an APK link, a Google Drive share page) is
  /// downloaded and installed by hand, so the person needs the steps.
  bool get opensStore {
    final url = Uri.tryParse(downloadUrl);

    if (url == null) {
      return false;
    }

    if (url.scheme == 'market' || url.scheme == 'itms-apps') {
      return true;
    }

    return const {
      'play.google.com',
      'apps.apple.com',
      'itunes.apple.com',
      'testflight.apple.com',
    }.contains(url.host);
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'build_number': buildNumber,
    'force_update': forceUpdate,
    'download_url': downloadUrl,
    'release_notes': releaseNotes,
  };
}

/// The new application this app has moved to: a different package, installed
/// next to this one. Only metadata; nothing is installed or removed for the
/// person.
class AppReplacement {
  const AppReplacement({
    required this.package,
    required this.downloadUrl,
    this.message,
  });

  final String package;
  final String downloadUrl;
  final String? message;

  /// Null for anything that is not a usable replacement: not an object, no
  /// package, or a download link that is not https. The notice is optional,
  /// so an unreadable one is dropped, never guessed.
  static AppReplacement? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }

    final package = raw['package'];
    final url = raw['download_url'];
    final message = raw['message'];

    if (package is! String || package.trim().isEmpty || url is! String) {
      return null;
    }

    final uri = Uri.tryParse(url.trim());

    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return null;
    }

    return AppReplacement(
      package: package.trim(),
      downloadUrl: url.trim(),
      message: message is String && message.trim().isNotEmpty
          ? message.trim()
          : null,
    );
  }
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

  return latest.forceUpdate
      ? UpdateRequirement.required
      : UpdateRequirement.optional;
}
