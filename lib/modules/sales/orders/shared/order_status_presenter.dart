import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../shared/models/order_type_presenter.dart';
import '../../shared/models/pos_order_type_store.dart';
class OrderStatusPresentation {
  const OrderStatusPresentation({required this.label, required this.color});

  final String label;
  final Color color;
}

class OrderStatusPresenter {
  static String getLocalizedOrderType(BuildContext context, String? orderType) {
    final types = PosOrderTypeStore.instance.snapshot.allOrderTypes.isNotEmpty
        ? PosOrderTypeStore.instance.snapshot.allOrderTypes
        : PosOrderTypeStore.instance.snapshot.orderTypes;
    final l10n = AppLocalizations.of(context);
    final displayName = OrderTypePresenter.getDisplayName(
      orderType,
      types,
      l10n: l10n,
    );
    if (displayName.isNotEmpty && displayName != '—' && displayName != '-') {
      return displayName;
    }
    if (types.isNotEmpty) {
      return types.first.name;
    }
    return l10n?.dineIn ?? 'Dine In';
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
        label: l10n.orderStatusUnknown,
        color: const Color(0xFF9CA3AF),
      );
  }
}
