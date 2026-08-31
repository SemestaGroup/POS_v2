import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import 'order_type_resolver.dart';
import 'pos_order_type.dart';

class OrderTypePresenter {
  const OrderTypePresenter._();

  static const Map<String, String> _legacyDisplayNames = <String, String>{
    'dine_in': 'Dine In',
    'dinein': 'Dine In',
    'take_away': 'Take Away',
    'takeaway': 'Take Away',
    'shopee_food': 'ShopeeFood',
    'shopeefood': 'ShopeeFood',
    'go_food': 'GoFood',
    'gofood': 'GoFood',
    'grab_food': 'GrabFood',
    'grabfood': 'GrabFood',
    'tiktok': 'TikTok',
    'tik_tok': 'TikTok',
    'tiktok_shop': 'TikTok Shop',
  };

  /// Get user-friendly display name for an order type code.
  /// Priority:
  /// 1. [PosOrderType.name] from active master list (direct or legacy alias match via [OrderTypeResolver.resolveCode]).
  /// 2. AppLocalizations string if matching built-in type.
  /// 3. Static legacy display name (e.g. "Dine In", "Take Away").
  /// 4. Humanized title case string (e.g. "drive_thru" -> "Drive Thru").
  static String getDisplayName(
    String? code,
    List<PosOrderType> activeTypes, {
    AppLocalizations? l10n,
  }) {
    if (code == null || code.trim().isEmpty) return '—';
    final trimmed = code.trim();
    final lower = trimmed.toLowerCase();

    // 1. Direct or alias match in active master
    final resolvedCode = OrderTypeResolver.resolveCode(trimmed, activeTypes);
    if (resolvedCode != null) {
      for (final ot in activeTypes) {
        if (ot.code.trim().toLowerCase() == resolvedCode.toLowerCase()) {
          return ot.name;
        }
      }
    }

    // 2. Fallback to AppLocalizations string when master is empty / not synced
    if (l10n != null) {
      final canonicalAlias = OrderTypeResolver.legacyCodeMap[lower] ?? lower;
      if (canonicalAlias == 'dinein') return l10n.dineIn;
      if (canonicalAlias == 'takeaway') return l10n.takeAway;
    }

    // 3. Static legacy display name lookup
    final legacyName = _legacyDisplayNames[lower] ??
        _legacyDisplayNames[OrderTypeResolver.legacyCodeMap[lower] ?? ''];
    if (legacyName != null) {
      return legacyName;
    }

    // 4. Humanize fallback
    return humanizeCode(trimmed);
  }

  /// Icon for a given order type code.
  static IconData getIconForOrderType(String code) {
    final lower = code.toLowerCase();
    if (lower.contains('dine')) return Icons.table_restaurant_outlined;
    if (lower.contains('take') || lower.contains('bawa')) return Icons.shopping_bag_outlined;
    if (lower.contains('tiktok')) return Icons.music_note_outlined;
    if (lower.contains('shopee')) return Icons.storefront_outlined;
    if (lower.contains('go') || lower.contains('gofood')) return Icons.delivery_dining_outlined;
    if (lower.contains('grab')) return Icons.local_shipping_outlined;
    return Icons.receipt_long_outlined;
  }

  /// Humanizes a raw code string (e.g., "drive_thru" -> "Drive Thru").
  static String humanizeCode(String code) {
    if (code.isEmpty) return code;
    final parts =
        code.replaceAll(RegExp(r'[-_]+'), ' ').trim().split(RegExp(r'\s+'));
    final capitalized = parts.map((part) {
      if (part.isEmpty) return '';
      return part[0].toUpperCase() + part.substring(1).toLowerCase();
    });
    return capitalized.join(' ');
  }
}
