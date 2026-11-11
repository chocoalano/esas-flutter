extension StringGuard on String? {
  /// Returns the string if it is not null, not empty, and not literally "null";
  /// otherwise returns [placeholder] (default: "-").
  String orPlaceholder([String placeholder = '-']) {
    final v = this;
    if (v == null || v.isEmpty || v == 'null') return placeholder;
    return v;
  }
}
