/// Every path this app requests, in one place.
///
/// ## The `/api/v1` surface
///
/// These are the paths `tenancy-app` actually answers, verified against its
/// `routes/api.php`. They are **not** the paths the pre-refactor app used: it
/// called `/api/general-module/...` and `/api/hris-module/...` — two namespaces
/// named after the backend's internal module layout, on a server
/// (`esas-erp-api-modulars`) that ADR-0006 retires.
///
/// ```
/// before   https://:9443/api/general-module/auth/login
///                                       ^^^^^^^^^^^^^^ backend module layout
/// after    https://hrms.example.com/api/v1/auth/login          + X-Tenant: acme
///                                       ^^^ one surface, shared with the kiosk
/// ```
///
/// The intermediate `/api/selfservice` this file was written against is gone.
/// It was a candidate namespace, never a live one, and ADR-0007 settled on the
/// prefix `esas_attendance` already runs against — see [Env.apiPrefix] for why
/// a second namespace was not worth what it cost.
///
/// ## What is relative to what
///
/// Paths here are relative to [Env.apiPrefix], so they never repeat it. A build
/// can be pointed somewhere else without touching this file:
///
/// ```
/// flutter run --dart-define=API_PREFIX=/api/v2
/// ```
///
/// ## Collections are Laravel paginators
///
/// Every list endpoint answers `{data, current_page, per_page, total, ...}` and
/// takes `page` and `per_page`. The old backend's `limit` is not a synonym and
/// is ignored where it is sent.
///
/// ## Writes take an `Idempotency-Key`
///
/// `POST /permits` and `POST /permits/{id}/approval` require one and answer a
/// repeat with the first response rather than filing a second request. See
/// `ApiClient`.
class ApiRoutes {
  const ApiRoutes._();

  // ── Platform ─────────────────────────────────────────────────────────────

  /// Does this name reach a workspace, and which one.
  ///
  /// Answered by the platform surface, [Env.platformApiPrefix], and asked
  /// before there is an account to ask as. `WorkspaceApiService` composes the
  /// full URL, because at the moment it is asked the address it is asked *of*
  /// is still a candidate rather than a setting. The two prefixes now hold the
  /// same value, but the distinction is real and is kept.
  static const String workspace = '/workspace';

  // ── Authentication ───────────────────────────────────────────────────────

  /// `identifier` (NIP **or** email) + `password` + `device_id`.
  static const String login = '/auth/login';

  /// **POST**, not GET. An optional `fcm_token` in the body releases this
  /// handset from the notification registry on the way out.
  static const String logout = '/auth/logout';

  /// Who this token belongs to. Says who you are; it does not carry the
  /// employee record — that is [profile].
  static const String currentUser = '/auth/me';

  /// `current_password` + `password` + `password_confirmation`. Revokes every
  /// other token and keeps this one.
  static const String changePassword = '/auth/password';

  /// Where this account is signed in, and releasing a handset it no longer has.
  static const String devices = '/auth/devices';
  static const String forgetDevice = '/auth/devices/forget';

  // ── Push ─────────────────────────────────────────────────────────────────

  /// `{token, platform}`. Registered against the token rather than the person,
  /// so a phone handed on moves rather than notifying two people.
  static const String pushToken = '/push-tokens';
  static const String forgetPushToken = '/push-tokens/forget';

  // ── Profile ──────────────────────────────────────────────────────────────

  /// The whole employee record: user, company, employment, personal detail,
  /// addresses, families, educations, experiences. This is what the five
  /// profile tabs read, and what stops the app treating the login payload as a
  /// record that never goes stale.
  static const String profile = '/profile';

  /// Replace this person's photograph. Multipart, field `file`.
  ///
  /// The one write in self-service that touches the employee record, and the
  /// narrowest possible one.
  static const String avatar = '/profile/avatar';

  /// Wage components — **not** a payslip. Salary, grade, bank, settled runs.
  static const String payroll = '/payroll';
  static const String payslips = '/payroll/slips';
  static String payslip(int id) => '$payslips/$id';
  static String payslipPdf(int id) => '$payslips/$id/pdf';

  // ── Home ─────────────────────────────────────────────────────────────────

  /// The clock-in screen's whole context: shift, today's attendance,
  /// `next_presence`, geofence, `attendance_enabled`, `face_enrolled`,
  /// `can_issue_qr`, `server_time`. Takes no employee — the token names them.
  static const String attendanceContext = '/attendance/context';

  /// The roster, with public holidays folded in. `from` / `to`, capped.
  static const String schedule = '/me/schedule';

  /// Leave remaining, per type that keeps a balance.
  static const String leaveBalance = '/me/leave-balance';

  /// This person's overtime. Read-only: overtime is asked for by whoever runs
  /// the shift, not by the person who would be paid for it.
  static const String overtime = '/me/overtime';

  /// What this account has been doing — the security screen.
  static const String activity = '/activities';

  // ── Announcements ────────────────────────────────────────────────────────

  /// `?active=1` narrows to published notices. A filter, not a second endpoint.
  static const String announcements = '/announcements';

  static String announcement(Object id) => '/announcements/$id';

  // ── Notifications ────────────────────────────────────────────────────────

  static const String notifications = '/notifications';

  /// **PATCH**. Marking one read is a change to it, not a read of it — the old
  /// backend answered this on a GET.
  static String readNotification(Object id) => '/notifications/$id/read';

  // ── Support ──────────────────────────────────────────────────────────────

  static const String bugReports = '/bug-reports';

  // ── Attendance ───────────────────────────────────────────────────────────

  /// The employee's own attendance. Named for the domain, not for the table it
  /// came out of — `/user-attendances` was the table.
  static const String attendances = '/attendances';

  /// The same window, counted: worked days, late arrivals, leave, absence.
  static const String attendanceSummary = '/attendance/summary';

  /// Clock with a code read off an attendance MACHINE's screen. Single-use,
  /// enforced by a unique index rather than by a check.
  ///
  /// Replaces `http://128.199.111.239:3000/attmachine/qr-presence` — a
  /// hardcoded cleartext address, on a bare IP, written inline in
  /// `AttendanceController` behind a local `const` that shadowed the app's own
  /// `baseApiUrl`. It now resolves through the same tenant-aware,
  /// TLS-terminated client as everything else, which closes HIGH-09 rather than
  /// relocating it.
  ///
  /// Takes `code` — the opaque `base64url(payload).base64url(hmac)` string the
  /// machine displays — plus `type`, and optional coordinates. **Not** the
  /// department code below: the two carry different payloads and are answered by
  /// different controllers, and the client used to post one to the other.
  static const String kioskQr = '/attendance/qr';

  /// Clock with a code a DEPARTMENT is displaying.
  ///
  /// The other half of QR attendance, and the one every employee uses. The code
  /// is a JSON object — `{tenant, token, type, expires_at}` — issued by
  /// `qr-presences` and read by [QrPayload]. The server checks the department,
  /// the expiry and single use; a client-side check is UX, not a control.
  static const String qrPresenceRedeem = '/qr-presences/redeem';

  /// Ask for the gestures this person must perform in front of the camera.
  ///
  /// Issued per attempt, **after** the person has asked to clock — never
  /// earlier, or a recording made in advance would answer it. The direction of
  /// travel goes with the request because the challenge is bound to it: one
  /// taken for a clock-in cannot be spent on a clock-out.
  static const String faceChallenge = '/attendance/face/challenge';

  /// Send the still, the signed challenge and what ML Kit saw on the handset.
  ///
  /// Multipart: `image`, `challenge_token`, `liveness` (a JSON document), `type`
  /// and optional coordinates. The server cannot verify the measurements — it
  /// has no recording — but it checks that they answer the challenge it drew,
  /// and keeps them on the verification row so a disputed refusal has evidence
  /// behind it.
  static const String faceAttendance = '/attendance/face';

  // ── Permits ──────────────────────────────────────────────────────────────

  static const String permitTypes = '/permit-types';

  /// `?type=` narrows to one kind; `?inbox=1` returns what is waiting on this
  /// person's decision instead of what they asked for.
  static const String permits = '/permits';

  /// The form's reference data: the person's own roster rows and the shifts a
  /// swap may name. Takes no company, department or employee — all three used
  /// to be sent and all three are the token's.
  static const String permitForm = '/permits/form';

  static String permit(Object id) => '/permits/$id';

  /// **POST**, `{decision: 'y'|'n', notes}`. The old backend took a PUT with an
  /// `approval_id`; which tier is being answered is the server's to decide, and
  /// answering out of turn is refused rather than recorded.
  static String permitApproval(Object id) => '/permits/$id/approval';
}
