import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

class OrderStatusPresentation {
  const OrderStatusPresentation({required this.label, required this.color});

  final String label;
  final Color color;
}

class OrderStatusPresenter {
  static String getLocalizedOrderType(BuildContext context, String orderType) {
    switch (orderType.toLowerCase()) {
      case 'dine_in':
        return 'Dine In';
      case 'take_away':
        return 'Take Away';
      default:
        return orderType.toUpperCase();
    }
  }

  static String getLocalizedStatusCode(BuildContext context, int statusCode) {
    return presentOrderStatus(context, statusCode).label;
  }
}

OrderStatusPresentation presentOrderStatus(
  BuildContext context,
  int statusCode,
) {
  final l10n = AppLocalizations.of(context)!;

  switch (statusCode) {
    case 1:
      return OrderStatusPresentation(
        label: l10n.orderStatusActive,
        color: const Color(0xFF2563EB),
      );
    case 2:
      return OrderStatusPresentation(
        label: l10n.orderStatusClosed,
        color: const Color(0xFF2E7D32),
      );
    case 3:
      return OrderStatusPresentation(
        label: l10n.orderStatusPartially,
        color: const Color(0xFFFB8C00),
      );
    case 4:
      return OrderStatusPresentation(
        label: l10n.orderStatusOverdue,
        color: const Color(0xFFEF6C00),
      );
    case 5:
      return OrderStatusPresentation(
        label: l10n.orderStatusVoid,
        color: const Color(0xFF6B7280),
      );
    case 6:
      return OrderStatusPresentation(
        label: l10n.orderStatusParked,
        color: const Color(0xFF7C3AED),
      );
    default:
      return OrderStatusPresentation(
        label: '$statusCode',
        color: const Color(0xFF6B7280),
      );
  }
}
