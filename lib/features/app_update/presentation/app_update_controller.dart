import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/storage/local_storage.dart';
import '../data/app_version_info.dart';

/// Asks the server which version is current and decides whether this
/// installation must, may, or need not update.
///
/// Checks when the app starts, when it comes back to the foreground, and every
/// [interval] while it is open - one request at a time. A failed request is
/// never an instruction to update: the last mandatory update that was seen is
/// kept (until the installed build catches up), and nothing else is assumed.
class AppUpdateController extends GetxController with WidgetsBindingObserver {
  AppUpdateController({
    required Future<AppVersionInfo?> Function() fetchLatest,
    required Future<int?> Function() installedBuild,
    required Future<bool> Function(Uri url) openUrl,
    required LocalStorage storage,
    Future<String?> Function()? installedPackage,
    this.interval = const Duration(seconds: 60),
  }) : _fetchLatest = fetchLatest,
       _installedBuild = installedBuild,
       _openUrl = openUrl,
       _storage = storage,
       _installedPackage = installedPackage;

  static const String storageKey = 'app_update.last_required';
  static const String migrationDismissedKey = 'app_update.migration_dismissed';

  final Future<AppVersionInfo?> Function() _fetchLatest;
  final Future<int?> Function() _installedBuild;
  final Future<bool> Function(Uri url) _openUrl;
  final LocalStorage _storage;
  final Future<String?> Function()? _installedPackage;
  final Duration interval;

  final Rx<UpdateRequirement> requirement = UpdateRequirement.none.obs;
  final Rxn<AppVersionInfo> latest = Rxn<AppVersionInfo>();
  final RxBool openFailed = false.obs;

  /// The build installed on this phone, as last read. Shown on the update
  /// screen so HR/IT can tell an install that did not happen from a file
  /// that carries the old build number.
  final RxnInt installedBuildNumber = RxnInt();

  /// The optional update the person closed; asked again only for a newer build.
  final RxnInt dismissedBuild = RxnInt();

  /// The replacement app to move to, when the server names a package other
  /// than this one. Null when there is none, it is this very package, or this
  /// package is unknown. Never blocks the app.
  final Rxn<AppReplacement> migration = Rxn<AppReplacement>();

  /// `<build>|<package>` of the notice the person closed. A different build or
  /// a different replacement package is a new notice.
  final RxnString dismissedMigration = RxnString();

  int? _migrationBuild;

  Timer? _timer;
  Future<void>? _inFlight;

  bool get showOptional =>
      requirement.value == UpdateRequirement.optional &&
      dismissedBuild.value != latest.value?.buildNumber;

  bool get showMigration =>
      migration.value != null && dismissedMigration.value != _migrationKey();

  String? _migrationKey() {
    final replacement = migration.value;
    final build = _migrationBuild;

    return replacement == null || build == null
        ? null
        : '$build|${replacement.package}';
  }

  @override
  void onInit() {
    super.onInit();
    dismissedMigration.value = _storage.read<String>(migrationDismissedKey);
    WidgetsBinding.instance.addObserver(this);
    unawaited(check());
    _timer = Timer.periodic(interval, (_) => unawaited(check()));
  }

  @override
  void onClose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(check());
    }
  }

  /// One check at a time: a call made while one is running waits for that one
  /// instead of sending a second request.
  Future<void> check() =>
      _inFlight ??= _check().whenComplete(() => _inFlight = null);

  Future<void> _check() async {
    final installed = await _installedBuild();

    if (installed == null) {
      return;
    }

    installedBuildNumber.value = installed;

    final package = await _installedPackage?.call();

    AppVersionInfo? current;

    try {
      current = await _fetchLatest();
    } catch (_) {
      // Could not ask. Keep only a mandatory update already known to apply.
      migration.value = null;
      _apply(installed, _rememberedRequired(installed));
      return;
    }

    final moved = _movedTo(current, package);

    migration.value = moved;
    _migrationBuild = moved == null ? null : current?.buildNumber;
    // Moving to another package and updating this one are different
    // processes; the server never sends both, and a replacement wins.
    final forThisPackage = moved == null ? current : null;

    _apply(installed, forThisPackage);
    await _remember(installed, forThisPackage);
  }

  /// Open the download link the superadmin set.
  Future<void> openDownload() async {
    final url = Uri.tryParse(latest.value?.downloadUrl ?? '');

    var opened = false;

    if (url != null && url.hasScheme) {
      try {
        opened = await _openUrl(url);
      } catch (_) {
        opened = false;
      }
    }

    openFailed.value = !opened;
  }

  void dismissOptional() => dismissedBuild.value = latest.value?.buildNumber;

  /// Open the new app's download link. Nothing is opened until the person asks.
  Future<void> openReplacement() async {
    final url = Uri.tryParse(migration.value?.downloadUrl ?? '');

    var opened = false;

    if (url != null && url.hasScheme) {
      try {
        opened = await _openUrl(url);
      } catch (_) {
        opened = false;
      }
    }

    migrationOpenFailed.value = !opened;
  }

  final RxBool migrationOpenFailed = false.obs;

  Future<void> dismissMigration() async {
    final key = _migrationKey();

    if (key == null) {
      return;
    }

    dismissedMigration.value = key;
    await _storage.write(migrationDismissedKey, key);
  }

  AppReplacement? _movedTo(AppVersionInfo? current, String? package) {
    final replacement = current?.replacement;

    if (replacement == null ||
        package == null ||
        package.isEmpty ||
        replacement.package == package) {
      return null;
    }

    return replacement;
  }

  void _apply(int installed, AppVersionInfo? current) {
    latest.value = current;
    requirement.value = evaluateUpdate(
      installedBuild: installed,
      latest: current,
    );

    if (requirement.value != UpdateRequirement.required) {
      openFailed.value = false;
    }
  }

  AppVersionInfo? _rememberedRequired(int installed) {
    final raw = _storage.read<String>(storageKey);

    if (raw == null) {
      return null;
    }

    try {
      final stored = AppVersionInfo.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );

      return stored != null &&
              stored.forceUpdate &&
              installed < stored.buildNumber
          ? stored
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _remember(int installed, AppVersionInfo? current) async {
    if (current != null &&
        evaluateUpdate(installedBuild: installed, latest: current) ==
            UpdateRequirement.required) {
      await _storage.write(storageKey, jsonEncode(current.toJson()));
    } else {
      await _storage.remove(storageKey);
    }
  }
}
