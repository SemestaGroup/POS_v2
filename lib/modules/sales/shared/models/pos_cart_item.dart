class PosCartItem {
  const PosCartItem({
    required this.id,
    required this.name,
    required this.displayName,
    required this.imageUrl,
    required this.regularUnitPrice,
    required this.quantity,
    this.productRemoteId,
    this.brandName,
    this.discountedUnitPrice,
    this.promoLabel,
    this.isDiscountEnabled = false,
    this.orderType,
    this.note,
    this.appliedPromoId,
    this.appliedPromoName,
    this.overriddenUnitPrice,
  });

  final String id;
  final String name;
  final String displayName;
  final String imageUrl;
  final int regularUnitPrice;
  final int quantity;
  final String? productRemoteId;
  final String? brandName;
  final int? discountedUnitPrice;
  final String? promoLabel;
  final bool isDiscountEnabled;
  final String? orderType;
  final String? note;
  final String? appliedPromoId;
  final String? appliedPromoName;
  final int? overriddenUnitPrice;

  int get activeUnitPrice {
    if (overriddenUnitPrice != null) {
      return overriddenUnitPrice!;
    }
    return isDiscountEnabled && discountedUnitPrice != null
        ? discountedUnitPrice!
        : regularUnitPrice;
  }

  PosCartItem copyWith({
    String? id,
    String? name,
    String? displayName,
    String? imageUrl,
    int? regularUnitPrice,
    int? quantity,
    String? productRemoteId,
    String? brandName,
    int? discountedUnitPrice,
    String? promoLabel,
    bool? isDiscountEnabled,
    String? orderType,
    String? note,
    bool clearNote = false,
    String? appliedPromoId,
    bool clearAppliedPromoId = false,
    String? appliedPromoName,
    bool clearAppliedPromoName = false,
    int? overriddenUnitPrice,
    bool clearOverriddenUnitPrice = false,
    bool clearDiscountedUnitPrice = false,
    bool clearPromoLabel = false,
  }) {
    return PosCartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      imageUrl: imageUrl ?? this.imageUrl,
      regularUnitPrice: regularUnitPrice ?? this.regularUnitPrice,
      quantity: quantity ?? this.quantity,
      productRemoteId: productRemoteId ?? this.productRemoteId,
      brandName: brandName ?? this.brandName,
      promoLabel: clearPromoLabel ? null : (promoLabel ?? this.promoLabel),
      isDiscountEnabled: isDiscountEnabled ?? this.isDiscountEnabled,
      orderType: orderType ?? this.orderType,
      note: clearNote ? null : (note ?? this.note),
      appliedPromoId: clearAppliedPromoId
          ? null
          : (appliedPromoId ?? this.appliedPromoId),
      appliedPromoName: clearAppliedPromoName
          ? null
          : (appliedPromoName ?? this.appliedPromoName),
      overriddenUnitPrice: clearOverriddenUnitPrice
          ? null
          : (overriddenUnitPrice ?? this.overriddenUnitPrice),
      discountedUnitPrice: clearDiscountedUnitPrice
          ? null
          : (discountedUnitPrice ?? this.discountedUnitPrice),
    );
  }
}
