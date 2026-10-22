import 'package:flutter/foundation.dart';

import 'consent_element.dart';

/// Outcome of the rule checker for one element.
///
/// [uncertain] is shown in amber like [missing], so the researcher checks it.
enum RuleStatus { ok, missing, uncertain }

/// The rule checker's verdict on one required element (Figma G).
final class RuleItem {
  /// Throws an [ArgumentError] when a non-ok item has no [fixHint].
  RuleItem({required this.element, required this.status, this.fixHint}) {
    final hint = fixHint;
    if (hint != null && hint.trim().isEmpty) {
      throw ArgumentError.value(hint, 'fixHint', 'Is blank');
    }
    if (status != RuleStatus.ok && hint == null) {
      throw ArgumentError.value(fixHint, 'fixHint', 'Required unless ok');
    }
  }

  final ConsentElement element;
  final RuleStatus status;

  /// What the researcher should add or check.
  final String? fixHint;

  @override
  bool operator ==(Object other) =>
      other is RuleItem &&
      other.element == element &&
      other.status == status &&
      other.fixHint == fixHint;

  @override
  int get hashCode => Object.hash(element, status, fixHint);
}

/// Result of the rule checker for one draft, one item per required element.
///
/// Mirrors `/schemas/rule_report.schema.json`.
final class RuleReport {
  /// Throws an [ArgumentError] when [items] is empty or repeats an element.
  RuleReport({required List<RuleItem> items})
    : items = List.unmodifiable(items) {
    if (items.isEmpty) {
      throw ArgumentError.value(items, 'items', 'Must not be empty');
    }
    final elements = items.map((item) => item.element).toSet();
    if (elements.length != items.length) {
      throw ArgumentError.value(items, 'items', 'One item per element');
    }
  }

  final List<RuleItem> items;

  /// Number of items with status [RuleStatus.ok].
  int get found => items.where((item) => item.status == RuleStatus.ok).length;

  /// Number of required elements: 10, or 14 for studies with minors.
  int get required => items.length;

  @override
  bool operator ==(Object other) =>
      other is RuleReport && listEquals(other.items, items);

  @override
  int get hashCode => Object.hashAll(items);
}
