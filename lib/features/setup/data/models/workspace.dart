import '../../../../core/tenancy/workspace_clock.dart';
import '../../../../core/utils/json_parsers.dart';

/// A workspace, as the server names it back during setup.
///
/// The point of the whole probe is [name]: `acme` reaching a workspace called
/// "Globex" is a mistake worth seeing before payroll depends on it, and an "OK"
/// that proves only that *something* answered would hide exactly that.
class Workspace {
  const Workspace({
    required this.subdomain,
    required this.name,
    required this.clock,
    this.apiVersion,
  });

  /// What the server calls this workspace — `acme`.
  final String subdomain;

  /// The company's display name, shown back to the person setting up.
  final String name;

  /// The contract version the server answers on, where it says so.
  ///
  /// Sent by `tenancy-app` as `api_version`. Kept because a build compiled
  /// against a contract the server no longer serves should say so at setup
  /// rather than failing at the gate on somebody's first morning.
  final String? apiVersion;

  /// Which of Indonesia's three clocks this workspace runs on.
  ///
  /// Asked here, before anybody signs in, because the setup screen is the first
  /// place a wrong answer would show — and because the login screen itself
  /// draws times. A server that predates the field yields WIB, which is what
  /// that server was itself running on.
  final WorkspaceClock clock;

  /// Read the probe's answer.
  ///
  /// [fallback] is what was typed, used when the server answers without naming
  /// itself. A workspace that confirmed but has no display name still confirmed;
  /// showing the code back is honest, showing nothing looks like a failure.
  factory Workspace.fromJson(
    Map<String, dynamic> json, {
    required String fallback,
  }) {
    final subdomain = asString(json['subdomain']);
    final name = asString(json['name']);

    return Workspace(
      subdomain: subdomain == null || subdomain.isEmpty ? fallback : subdomain,
      name: name == null || name.isEmpty ? fallback : name,
      apiVersion: asString(json['api_version']),
      clock: WorkspaceClock.fromJson(json['timezone']),
    );
  }
}
