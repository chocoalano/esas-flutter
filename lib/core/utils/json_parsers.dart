/// Null-safe accessors for decoded JSON.
///
/// The models used two incompatible styles: all-nullable fields with unchecked
/// map reads, and 40 non-null casts of the form `json['id'] as int` that throw
/// the moment the backend sends null or shifts a type (MED-04).
///
/// The throw is the smaller half of the problem. `HomeController` catches it and
/// rethrows `FormatException('Response format tidak sesuai')`, which **erases
/// the field name** — so a production parse failure says only that something,
/// somewhere, was shaped wrong.
///
/// A note on defaults, from R-10: a field that used to throw will now return a
/// default, which turns a loud failure into a quiet one. So the defaults here
/// are visibly empty — null, zero, an em dash at the call site — and never a
/// plausible-looking value. For an HRMS, a wrong number that looks right is
/// worse than a blank.
library;

import 'app_logger.dart';

/// An int from an int, a num, or a numeric string. Null otherwise.
///
/// Accepting a string matters: the attendance QR code carries `departement_id`
/// and `id` as JSON values whose type is not guaranteed, and the old code called
/// `int.tryParse` on them — which takes a non-nullable `String` and throws a
/// `TypeError` outright when handed a number (CRIT-04).
int? asInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    final trimmed = value.trim();

    return trimmed.isEmpty ? null : int.tryParse(trimmed);
  }

  return null;
}

double? asDouble(Object? value) {
  if (value is double) {
    return value;
  }

  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    final trimmed = value.trim();

    return trimmed.isEmpty ? null : double.tryParse(trimmed);
  }

  return null;
}

/// A string from anything that has one. Blank reads as absent, because the
/// backend uses `""` and `null` interchangeably for an unset field.
String? asString(Object? value) {
  if (value == null) {
    return null;
  }

  if (value is String) {
    final trimmed = value.trim();

    return trimmed.isEmpty ? null : trimmed;
  }

  return value.toString();
}

bool? asBool(Object? value) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  if (value is String) {
    return switch (value.trim().toLowerCase()) {
      'true' || '1' || 'yes' || 'y' => true,
      'false' || '0' || 'no' || 'n' => false,
      _ => null,
    };
  }

  return null;
}

/// A date from an ISO-8601 string, or from epoch milliseconds.
///
/// Never throws. `DateTime.parse(json['created_at'] as String)` appears 8 times
/// in the models and throws twice over on a null: once on the cast, once on the
/// parse.
DateTime? asDate(Object? value) {
  if (value is DateTime) {
    return value;
  }

  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  if (value is String) {
    final trimmed = value.trim();

    return trimmed.isEmpty ? null : DateTime.tryParse(trimmed);
  }

  return null;
}

/// A year, as the DateTime the profile screens format.
///
/// The HRIS keeps education and work-experience periods as **year integers** —
/// `start: 2014` — and the screens only ever render `DateFormat('yyyy')` from
/// them. The models declared `DateTime?` and parsed with `DateTime.tryParse`,
/// which takes a non-nullable `String`: handed the integer the column actually
/// holds, it throws a `TypeError` rather than returning null.
///
/// A full date string still parses, so a backend that ever starts sending one
/// does not need this changed.
DateTime? asYear(Object? value) {
  if (value is DateTime) {
    return value;
  }

  final year = asInt(value);

  // A four-digit year, not a timestamp somebody stored as a number.
  if (year != null && year > 1000 && year < 3000) {
    return DateTime(year);
  }

  final text = asString(value);

  return text == null ? null : DateTime.tryParse(text);
}

/// A nested object, or an empty map. Never null, so a chain of lookups does not
/// need a null check at every step.
Map<String, dynamic> asObject(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  return const {};
}

/// A list, or an empty one.
List<dynamic> asList(Object? value) {
  if (value is List) {
    return value;
  }

  return const [];
}

/// The rows out of a Laravel paginator.
///
/// Every collection on `/api/v1` answers `{data, current_page, per_page,
/// total, ...}` rather than a bare array. The page metadata is the reason —
/// the old backend returned a naked list and the app had to guess whether it
/// had reached the end — but it means a caller that reads the body as a list
/// gets nothing, silently, on every screen.
///
/// A bare array is still accepted. Not every endpoint is a paginator, and a
/// helper that only understood one of the two shapes would just move the guess.
List<dynamic> asPage(Object? value) {
  if (value is Map && value['data'] is List) {
    return value['data'] as List;
  }

  return asList(value);
}

/// Map a JSON array into models, skipping rows that cannot be parsed.
///
/// A single malformed row in a list of fifty should cost one row, not the whole
/// screen. That is what this comment has always claimed, and until now it was
/// only half true: rows that were not objects were skipped, but a `fromJson`
/// that *threw* took the entire list — and, because a `TypeError` is not an
/// `ApiException`, it sailed past the controller's `catch` and killed the
/// screen. One leave type with a null `type` emptied the whole Pengajuan tab.
///
/// The models are the right place to stop that, and most of them do it by
/// reading through the accessors above. Six still use raw `as` casts, so the
/// guarantee is enforced here too. It is a backstop, not a licence: a row that
/// lands in the `catch` is a bug in a model or a change in the API, so it is
/// logged at error level, which survives release builds.
List<T> asModelList<T>(
  Object? value,
  T Function(Map<String, dynamic> json) fromJson,
) {
  final models = <T>[];

  for (final entry in asList(value)) {
    if (entry is! Map) {
      continue;
    }

    try {
      models.add(fromJson(Map<String, dynamic>.from(entry)));
    } catch (error, stackTrace) {
      // The row itself is not logged: these lists carry employee records, and
      // a device log is not the place for them.
      AppLogger.error(
        'Melewati satu baris $T yang tidak bisa diurai',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  return models;
}

/// Walk a path of keys, returning null the moment one is missing.
///
/// Replaces `user?['employee']?['job_position']?['name']` chains, which are what
/// `avoid_dynamic_calls` exists to flag.
Object? dig(Object? root, List<String> path) {
  Object? current = root;

  for (final key in path) {
    if (current is! Map) {
      return null;
    }

    current = current[key];
  }

  return current;
}
