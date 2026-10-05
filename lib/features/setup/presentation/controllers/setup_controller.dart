import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:esas/features/auth/presentation/routes/auth_routes.dart';
import '../../../../core/config/env.dart';
import '../../../../core/config/server_config.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/repositories/workspace_repository.dart';

/// Setting a handset up: which server, and which company on it.
///
/// Ported from the sibling app `esas_attendance`, as ADR-0005 §4 asks — the
/// screen it describes is the one that was never built here, which is why one
/// signed binary could not actually serve more than the company named by
/// `--dart-define=TENANT` (finding CLI-01).
///
/// What is different from the sibling: the candidate is never written onto the
/// live configuration to be tested. `WorkspaceRepository.connect` composes it,
/// asks, and stores only what the server confirmed.
class SetupController extends GetxController {
  SetupController({required WorkspaceRepository repository})
    : _repository = repository;

  final WorkspaceRepository _repository;

  final formKey = GlobalKey<FormState>();
  final domainController = TextEditingController();
  final workspaceController = TextEditingController();

  final RxBool subdomainMode = true.obs;
  final RxBool isChecking = false.obs;

  /// Bumped on every keystroke.
  ///
  /// The two things this screen shows about what is being typed — the address a
  /// request would go to, and whether it is encrypted — are derived from text
  /// controllers, which are not observable. Without this they are computed once
  /// and never again, so the preview sits on a stale host while somebody
  /// corrects the field above it.
  final RxInt edits = 0.obs;

  /// The name the server answered with, once it has answered.
  ///
  /// What makes this screen a confirmation rather than a form: `acme` reaching a
  /// workspace called "Globex" is a mistake worth seeing before payroll depends
  /// on it.
  final RxnString confirmedName = RxnString();
  final RxnString checkError = RxnString();

  /// Whether this handset already has a workspace, in which case the screen was
  /// opened to change it and can be left without changing anything.
  bool get isReconfiguring => _repository.isConfigured;

  /// Whether what is typed now would send passwords in the clear. Read from the
  /// field rather than from the build — the address is typed in, so this changes
  /// as somebody types.
  bool get isInsecure {
    final normalised = ServerConfig.normalise(domainController.text);

    return normalised != null && !normalised.startsWith('https://');
  }

  /// Whether the address being typed can carry a workspace on its front.
  ///
  /// An IP cannot: `acme.172.16.2.233` is not a hostname and nothing resolves
  /// it. The switch is disabled rather than merely ignored, because a control
  /// that is on and has no effect is worse than one that is visibly unavailable
  /// — somebody sets it, sees the preview disagree, and mistrusts both.
  bool get supportsSubdomain {
    final domain = ServerConfig.normalise(domainController.text);

    if (domain == null) {
      return true;
    }

    return !ServerConfig.isIpLiteral(Uri.parse(domain).host);
  }

  /// Whether subdomain mode is actually in force: what was chosen, and what the
  /// address permits.
  bool get usesSubdomain => subdomainMode.value && supportsSubdomain;

  /// The API root a request would actually go to, shown under the fields so the
  /// effect of the subdomain switch is visible rather than described.
  ///
  /// Shows this client's own surface — `Env.apiPrefix` — because that is where
  /// every request after setup goes. The probe itself asks the platform surface
  /// (`Env.platformApiPrefix`); until ADR-0007 settles the namespace those two
  /// can differ, and the one worth showing is the one the app will live on.
  String get preview {
    final domain = ServerConfig.normalise(domainController.text);

    if (domain == null) {
      return '—';
    }

    final origin = ServerConfig.originOf(
      domain: domain,
      tenant: workspaceController.text,
      subdomainMode: usesSubdomain,
    );

    return '$origin${Env.apiPrefix}';
  }

  @override
  void onInit() {
    super.onInit();

    domainController.text = _repository.domain ?? '';
    workspaceController.text = _repository.workspace ?? '';
    subdomainMode.value = _repository.subdomainMode;

    // Any edit invalidates a confirmation that was about the old values.
    domainController.addListener(_invalidate);
    workspaceController.addListener(_invalidate);
  }

  @override
  void onClose() {
    domainController.removeListener(_invalidate);
    workspaceController.removeListener(_invalidate);
    domainController.dispose();
    workspaceController.dispose();
    super.onClose();
  }

  String? validateDomain(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Alamat server wajib diisi.';
    }

    return ServerConfig.normalise(value) == null
        ? 'Alamat server tidak dikenali. Contoh: hrms.perusahaan.co.id'
        : null;
  }

  String? validateWorkspace(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Kode workspace wajib diisi.';
    }

    return ServerConfig.isValidWorkspace(value)
        ? null
        : 'Gunakan huruf kecil, angka dan tanda hubung saja. Contoh: acme';
  }

  /// Ask the server to confirm what is typed, and store it only if it does.
  Future<void> check() async {
    // Paints the messages under the fields when there is a form on screen. The
    // values are checked again below regardless: a controller that refuses bad
    // input only while a widget happens to be mounted is one whose refusal
    // cannot be relied on, or tested.
    formKey.currentState?.validate();

    if (validateDomain(domainController.text) != null ||
        validateWorkspace(workspaceController.text) != null) {
      return;
    }

    final workspace = workspaceController.text.trim().toLowerCase();

    isChecking.value = true;
    checkError.value = null;
    confirmedName.value = null;

    try {
      final found = await _repository.connect(
        domain: domainController.text,
        workspace: workspace,
        // What the address permits, not what the switch was left on: storing
        // `true` against an IP would save a setting that silently does nothing.
        subdomainMode: usesSubdomain,
      );

      confirmedName.value = found.name;
    } on ApiException catch (error) {
      checkError.value = explain(error, workspace);
    } finally {
      isChecking.value = false;
    }
  }

  /// Move on to signing in, offered only once the server has confirmed the
  /// workspace.
  void proceed() {
    Get.offAllNamed(AuthRoutes.login);
  }

  /// Leave without changing anything, when the screen was opened to change a
  /// setting somebody then decided against.
  void cancel() {
    Get.back<void>();
  }

  void _invalidate() {
    edits.value++;

    // A confirmation, or a refusal, is about the values that were checked. Left
    // standing over an edited field, the confirmation would offer a way onward
    // for an address nothing has ever reached.
    if (confirmedName.value != null || checkError.value != null) {
      confirmedName.value = null;
      checkError.value = null;
    }
  }

  /// Say which of the two guesses was wrong.
  ///
  /// This is the whole reason the screen makes a request of its own. The server
  /// already distinguishes these — the tenant middleware answers 404 for a name
  /// that reaches no workspace and 400 for a request that names none — and the
  /// sign-in screen threw that distinction away.
  @visibleForTesting
  static String explain(ApiException error, String workspace) {
    if (error.isTransportFailure) {
      return 'Server tidak dapat dihubungi. Periksa alamat server dan koneksi Anda.';
    }

    return switch (error.status) {
      404 =>
        'Server menjawab, tetapi tidak mengenal workspace "$workspace". '
            'Tanyakan kode workspace Anda ke HR.',
      400 => 'Server tidak menerima kode workspace ini. Periksa penulisannya.',
      429 => 'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.',
      final int status when status >= 500 =>
        'Server sedang bermasalah. Hubungi administrator Anda.',
      _ => error.message,
    };
  }
}
