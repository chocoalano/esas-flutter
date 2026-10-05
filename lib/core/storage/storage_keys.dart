/// Keys for values kept on the device.
///
/// Split by *where* a value belongs, because the two stores answer different
/// questions. [Secure] is the keychain: credentials and the tenancy
/// configuration. [Local] is `GetStorage`: preferences and cached display data
/// that would be merely inconvenient to lose and harmless to leak.
///
/// [Legacy] holds the pre-migration flat keys. No code writes them any more —
/// the mirror was switched off at the end of Phase 5 — but an install upgrading
/// from an older build still has values under them, so they are named here for
/// the one-shot migration and for `clear()` to wipe.
class StorageKeys {
  const StorageKeys._();

  /// Keychain — credentials and tenancy.
  static const secure = _SecureKeys();

  /// GetStorage — preferences and cached display data.
  static const local = _LocalKeys();

  /// The pre-migration keys, all in GetStorage. Read by unmigrated code.
  static const legacy = _LegacyKeys();
}

class _SecureKeys {
  const _SecureKeys();

  String get token => 'esas.auth_token';
  String get tenant => 'esas.tenant';
  String get serverDomain => 'esas.server_domain';
  String get serverSubdomainMode => 'esas.server_subdomain_mode';
}

class _LocalKeys {
  const _LocalKeys();

  String get isDarkMode => 'isDarkMode';
  String get onboardingCompleted => 'onboarding_completed';
  String get userJson => 'auth_user_json';
  String get userName => 'auth_user_name';
  String get userId => 'auth_user_id';
  String get userNip => 'auth_user_nip';
  String get userAvatar => 'auth_user_avatar';

  /// Who has been SHOWN the biometric notice on this handset, and against which
  /// version of it.
  ///
  /// Deliberately not called consent. The consent that matters is recorded by
  /// HR against the enrolment — `hrms_user_face_references.consent_recorded_at`,
  /// which `UserFaceReference::isUsable()` requires before `face_enrolled` can
  /// ever be true. This key records only that a notice was displayed here before
  /// a camera opened, so it is not displayed again on every clock-in.
  ///
  /// Scoped three ways, and each one is a bug that would otherwise happen:
  ///
  /// * **employee** — a handset is passed on; Alan's acknowledgement is not
  ///   Budi's, and Budi must see the notice on his first face clock-in;
  /// * **workspace** — the same person id in two tenants is two people;
  /// * **version** — when the wording changes, the old acknowledgement must
  ///   stop suppressing the new text.
  String faceNoticeSeen({
    required Object employeeId,
    required String workspace,
    required int version,
  }) => 'face_notice.v$version.$workspace.$employeeId';
}

class _LegacyKeys {
  const _LegacyKeys();

  String get token => 'auth_token';
  String get tokenType => 'auth_token_type';
  String get userName => 'auth_user_name';
  String get userId => 'auth_user_id';
  String get userNip => 'auth_user_nip';

  /// The plaintext password. Written by the pre-migration login controller.
  ///
  /// Never read by new code, and deleted outright by the Phase 3 migration —
  /// see CRIT-03. Present here only so the wipe can name it.
  String get userPassword => 'auth_user_password';

  String get userAvatar => 'auth_user_avatar';
  String get userJson => 'auth_user_json';

  /// Every key a session wipe must clear. The three hand-written
  /// `clearStorage()` copies disagreed about this list; MED-05 is that
  /// disagreement.
  List<String> get sessionKeys => const [
    'auth_token',
    'auth_token_type',
    'auth_user_name',
    'auth_user_id',
    'auth_user_nip',
    'auth_user_password',
    'auth_user_avatar',
    'auth_user_json',
  ];
}
