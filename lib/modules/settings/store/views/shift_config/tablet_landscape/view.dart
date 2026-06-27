import 'package:flutter/material.dart';

import '../../../controllers/store_settings_controller.dart';
import '../../../models/store_settings_state.dart';

class ShiftConfigView extends StatefulWidget {
  const ShiftConfigView({super.key});

  @override
  State<ShiftConfigView> createState() => _ShiftConfigViewState();
}

class _ShiftConfigViewState extends State<ShiftConfigView> {
  final ShiftConfigController _controller = ShiftConfigController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ShiftConfigState>(
      valueListenable: _controller.stateNotifier,
      builder: (context, state, _) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title ───────────────────────────────────────────────────
              const Text(
                'Konfigurasi Shift',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              const Text(
                'Aturan operasional pembukaan shift, kas, dan disiplin perangkat.',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),

              // ── Quick Rules ──────────────────────────────────────────────
              const _SectionLabel('Aturan Kas & Shift'),
              const SizedBox(height: 8),
              _switchTile(
                title: 'Wajibkan Modal Awal',
                subtitle: 'Kasir wajib memasukkan saldo awal saat buka shift.',
                value: state.requireOpeningBalance,
                onChanged: (value) => _controller.updateQuickRules(
                    requireOpeningBalance: value),
              ),
              const SizedBox(height: 8),
              _switchTile(
                title: 'Auto Print Rekap Shift',
                subtitle: 'Cetak rekap otomatis saat shift ditutup.',
                value: state.autoPrintShiftRecap,
                onChanged: (value) =>
                    _controller.updateQuickRules(autoPrintShiftRecap: value),
              ),
              const SizedBox(height: 8),
              _switchTile(
                title: 'Izinkan Edit Saldo Akhir',
                subtitle:
                    'Kasir boleh mengubah hasil hitung kas fisik sebelum tutup shift.',
                value: state.allowEditActualCash,
                onChanged: (value) =>
                    _controller.updateQuickRules(allowEditActualCash: value),
              ),

              const SizedBox(height: 18),

              // ── Jadwal Shift ─────────────────────────────────────────────
              const _SectionLabel('Konfigurasi Jadwal Shift'),
              const SizedBox(height: 8),
              _switchTile(
                title: 'Aktifkan Pembatasan Jadwal Shift',
                subtitle:
                    'Jika aktif, hanya staf yang terdaftar di jadwal shift yang dapat membuka shift pada waktu tersebut.\n'
                    'Jika staf lain mencoba buka shift, akan muncul peringatan konfirmasi.',
                value: state.shiftScheduleEnabled,
                onChanged: (value) => _controller.updateShiftSchedule(
                    enabled: value),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFE69C)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 14, color: Color(0xFF856404)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Jika jadwal shift tidak dikonfigurasi: siapapun yang login dan membuka shift/outlet '
                        'akan dianggap bertanggung jawab atas shift tersebut tanpa batasan.\n\n'
                        'Jika jadwal shift aktif: hanya akun yang terdaftar untuk slot waktu tersebut yang dapat '
                        'membuka shift tanpa peringatan. Staf lain akan melihat popup konfirmasi:\n'
                        '"Anda akan menggantikan jadwal shift karyawan [Nama]. Lanjutkan?"',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.brown.shade700,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Device Discipline ────────────────────────────────────────
              const _SectionLabel('Disiplin Perangkat'),
              const SizedBox(height: 8),
              _infoCard(
                [
                  _InfoRow(
                    'Satu perangkat per staf',
                    state.enforceSingleDevicePerStaff ? 'Ya' : 'Tidak',
                  ),
                  _InfoRow(
                    'Wajib Device ID',
                    state.requireDeviceId ? 'Ya' : 'Tidak',
                  ),
                  _InfoRow(
                    'Self-Order aktif',
                    state.selfOrderEnabled ? 'Ya' : 'Tidak',
                  ),
                  _InfoRow('Mode operasional', state.operatingMode),
                ],
              ),

              if (state.errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    state.errorMessage!,
                    style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                        height: 1.45)),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _infoCard(List<_InfoRow> rows) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(row.label,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF6B7280))),
                    Text(row.value,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151))),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
            letterSpacing: 0.3),
      );
}

class _InfoRow {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
}
