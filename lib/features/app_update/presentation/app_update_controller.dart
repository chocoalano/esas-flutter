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
    this.interval = const Duration(seconds: 60),
  }) : _fetchLatest = fetchLatest,
       _installedBuild = installedBuild,
       _openUrl = openUrl,
       _storage = storage;

  static const String storageKey = 'app_update.last_required';

  final Future<AppVersionInfo?> Function() _fetchLatest;
  final Future<int?> Function() _installedBuild;
  final Future<bool> Function(Uri url) _openUrl;
  final LocalStorage _storage;
  final Duration interval;

  final Rx<UpdateRequirement> requirement = UpdateRequirement.none.obs;
  final Rxn<AppVersionInfo> latest = Rxn<AppVersionInfo>();
  final RxBool openFailed = false.obs;

  /// The optional update the person closed; asked again only for a newer build.
  final RxnInt dismissedBuild = RxnInt();

  Timer? _timer;
  Future<void>? _inFlight;

  bool get showOptional =>
      requirement.value == UpdateRequirement.optional &&
      dismissedBuild.value != latest.value?.buildNumber;

  @override
  void onInit() {
    super.onInit();
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
  Future<void> check() => _inFlight ??= _check().whenComplete(() => _inFlight = null);

  Future<void> _check() async {
    final installed = await _installedBuild();

    if (installed == null) {
      return;
    }

    AppVersionInfo? current;

    try {
      current = await _fetchLatest();
    } catch (_) {
      // Could not ask. Keep only a mandatory update already known to apply.
      _apply(installed, _rememberedRequired(installed));
      return;
    }

    _apply(installed, current);
    await _remember(installed, current);
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

  void _apply(int installed, AppVersionInfo? current) {
    latest.value = current;
    requirement.value = evaluateUpdate(installedBuild: installed, latest: current);

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
      final stored = AppVersionInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);

      return stored != null && stored.forceUpdate && installed < stored.buildNumber ? stored : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _remember(int installed, AppVersionInfo? current) async {
    if (current != null && evaluateUpdate(installedBuild: installed, latest: current) == UpdateRequirement.required) {
      await _storage.write(storageKey, jsonEncode(current.toJson()));
    } else {
      await _storage.remove(storageKey);
    }
  }
}
