import 'pos_order_type.dart';

class OrderTypeResolver {
  const OrderTypeResolver._();

  static const Map<String, String> legacyCodeMap = <String, String>{
    'dine_in': 'dinein',
    'dinein': 'dinein',
    'take_away': 'takeaway',
    'takeaway': 'takeaway',
    'shopee_food': 'shopeefood',
    'shopeefood': 'shopeefood',
    'go_food': 'gofood',
    'gofood': 'gofood',
    'grab_food': 'grabfood',
    'grabfood': 'grabfood',
  };

  /// Resolve a raw order type string to a matching active [PosOrderType.code].
  /// Returns `null` if [rawCode] is empty or no matching master order type exists.
  static String? resolveCode(String? rawCode, List<PosOrderType> activeTypes) {
    if (rawCode == null || rawCode.trim().isEmpty) return null;
    final trimmed = rawCode.trim();
    final lower = trimmed.toLowerCase();

    // 1. Direct match on master code
    for (final ot in activeTypes) {
      if (ot.code.trim().toLowerCase() == lower) {
        return ot.code;
      }
    }

    // 2. Legacy alias match on master code
    final mappedAlias = legacyCodeMap[lower];
    if (mappedAlias != null) {
      for (final ot in activeTypes) {
        if (ot.code.trim().toLowerCase() == mappedAlias) {
          return ot.code;
        }
      }
    }

    // 3. No match in master active order types -> return null
    return null;
  }

  /// Resolves the raw order type against [activeTypes].
  /// If [rawCode] resolves to a valid master code, returns it.
  /// If not and [activeTypes] is non-empty, returns the first active master code.
  /// If [activeTypes] is empty, returns [rawCode] (if not empty) or [fallback].
  static String resolveOrDefault(
    String? rawCode,
    List<PosOrderType> activeTypes, {
    String fallback = 'dinein',
  }) {
    final resolved = resolveCode(rawCode, activeTypes);
    if (resolved != null) return resolved;
    if (activeTypes.isNotEmpty) return activeTypes.first.code;
    return (rawCode != null && rawCode.trim().isNotEmpty)
        ? rawCode.trim()
        : fallback;
  }

  /// Reconciles currently selected order type against [activeTypes].
  /// If [activeTypes] is empty, preserves [currentSelected] (or [fallback] if null/empty).
  /// Otherwise, resolves against [activeTypes] or selects first active type.
  static String reconcileSelected({
    required String? currentSelected,
    required List<PosOrderType> activeTypes,
    String fallback = 'dinein',
  }) {
    if (activeTypes.isEmpty) {
      return (currentSelected != null && currentSelected.trim().isNotEmpty)
          ? currentSelected.trim()
          : fallback;
    }
    return resolveOrDefault(currentSelected, activeTypes, fallback: fallback);
  }
}

