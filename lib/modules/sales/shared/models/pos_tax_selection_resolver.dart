import '../../../../core/services/local/database_service.dart';

class PosTaxSelection {
  const PosTaxSelection._({
    required this.isEnabled,
    this.name,
    this.percentage = 0.0,
    this.issue,
  });

  const PosTaxSelection.disabled({String? issue})
    : this._(isEnabled: false, issue: issue);

  const PosTaxSelection.enabled({
    required String name,
    required double percentage,
  }) : this._(isEnabled: true, name: name, percentage: percentage);

  final bool isEnabled;
  final String? name;
  final double percentage;
  final String? issue;
}

abstract final class PosTaxSelectionResolver {
  static Future<PosTaxSelection> resolve({
    required bool autoTax,
    required String? selectedTaxId,
  }) async {
    final normalizedTaxId = selectedTaxId?.trim() ?? '';
    if (!autoTax || normalizedTaxId.isEmpty) {
      return fromRows(
        autoTax: autoTax,
        selectedTaxId: normalizedTaxId,
        rows: const <Map<String, dynamic>>[],
      );
    }

    final rows = await DatabaseService.instance.rawQuery(
      'SELECT name, taxrate FROM pos_tax WHERE remote_id = ? OR id = ? LIMIT 1',
      <Object?>[normalizedTaxId, normalizedTaxId],
    );
    return fromRows(
      autoTax: autoTax,
      selectedTaxId: normalizedTaxId,
      rows: rows,
    );
  }

  static PosTaxSelection fromRows({
    required bool autoTax,
    required String? selectedTaxId,
    required List<Map<String, dynamic>> rows,
  }) {
    if (!autoTax) return const PosTaxSelection.disabled();
    final normalizedTaxId = selectedTaxId?.trim() ?? '';
    if (normalizedTaxId.isEmpty) {
      return const PosTaxSelection.disabled(
        issue: 'Auto-tax aktif tetapi tax_id belum dikonfigurasi.',
      );
    }
    if (rows.isEmpty) {
      return PosTaxSelection.disabled(
        issue: 'Pajak terpilih ($normalizedTaxId) belum tersedia di perangkat.',
      );
    }

    final tax = rows.first;
    final name = tax['name']?.toString().trim() ?? '';
    final percentage = double.tryParse(tax['taxrate']?.toString() ?? '');
    if (name.isEmpty || percentage == null || percentage <= 0) {
      return PosTaxSelection.disabled(
        issue: 'Konfigurasi pajak $normalizedTaxId tidak valid.',
      );
    }
    return PosTaxSelection.enabled(name: name, percentage: percentage);
  }
}
