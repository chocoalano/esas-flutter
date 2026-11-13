import 'package:flutter/services.dart';

/// The activation code HR shows an employee once (ADR-D §4, D-SEC-01).
///
/// Ten symbols of Crockford Base32 — no `I`, `L`, `O` or `U` — displayed as
/// `XXXXX-XXXXX`. The normalisation here is the server's own (upper case, no
/// `-` or spaces, `O→0`, `I/L→1`), so what the employee types and what HR read
/// out are compared the same way on both sides. The server still decides; this
/// only stops an obviously incomplete code from being sent.
class EnrollmentCode {
  const EnrollmentCode._();

  static const String alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const int length = 10;
  static const int groupLength = 5;

  /// How long a code lives after HR issues it, as the PO decided (D-SEC-01:
  /// TTL 15 minutes). Said on the code screen up front, because the server
  /// deliberately answers an expired code exactly like a wrong one. The value
  /// is the server's config (`code_ttl_minutes`); change both together.
  static const int validityMinutes = 15;

  /// A whole code inside longer text — "Kode: ABCDE-12345" pasted from a chat.
  static final RegExp _embedded = RegExp(
    r'(?<![0-9A-Z])([0-9A-Z]{5})[-\s]?([0-9A-Z]{5})(?![0-9A-Z])',
  );

  /// Upper case, separators removed, look-alikes mapped. Characters outside the
  /// alphabet are kept, so [isValid] can refuse them.
  static String normalize(String input) {
    final buffer = StringBuffer();

    for (final rune in input.toUpperCase().runes) {
      final char = String.fromCharCode(rune);

      switch (char) {
        case '-' || ' ' || '\t' || '\n':
          continue;
        case 'O':
          buffer.write('0');
        case 'I' || 'L':
          buffer.write('1');
        default:
          buffer.write(char);
      }
    }

    return buffer.toString();
  }

  /// Exactly ten symbols, all from the alphabet.
  static bool isValid(String normalized) =>
      normalized.length == length &&
      normalized.split('').every(alphabet.contains);

  /// `XXXXX-XXXXX`, or as much of it as has been typed.
  static String format(String normalized) => normalized.length <= groupLength
      ? normalized
      : '${normalized.substring(0, groupLength)}-'
            '${normalized.substring(groupLength)}';

  /// [normalize], with anything outside the alphabet dropped and the length
  /// capped: what the input field holds.
  ///
  /// Text that CONTAINS a whole code (a pasted sentence) yields that code: the
  /// letters of "Kode:" are not the first four symbols of it.
  static String sanitize(String input) {
    final upper = input.toUpperCase();
    final whole = _embedded.allMatches(upper).lastOrNull;

    if (whole != null && whole.group(0) != upper.trim()) {
      return normalize(
        '${whole.group(1)}${whole.group(2)}',
      ).split('').where(alphabet.contains).join();
    }

    return normalize(
      input,
    ).split('').where(alphabet.contains).take(length).join();
  }
}

/// Keeps the field in `XXXXX-XXXXX` while the employee types.
class EnrollmentCodeInputFormatter extends TextInputFormatter {
  const EnrollmentCodeInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = EnrollmentCode.format(EnrollmentCode.sanitize(newValue.text));

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
