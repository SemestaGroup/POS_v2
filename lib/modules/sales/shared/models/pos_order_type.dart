class PosOrderType {
  const PosOrderType({
    required this.code,
    required this.name,
    this.description,
  });

  final String code;
  final String name;
  final String? description;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PosOrderType &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'PosOrderType(code: $code, name: $name)';
}
