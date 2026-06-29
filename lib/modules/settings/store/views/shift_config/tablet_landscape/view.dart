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
              const SizedBox(height: 8),

              // ── Quick Rules ──────────────────────────────────────────────
              const _SectionLabel('Aturan Kas & Shift'),
              const SizedBox(height: 2),
              _switchTile(
                title: 'Wajibkan Modal Awal',
                subtitle: 'Kasir wajib memasukkan saldo awal saat buka shift.',
                value: state.requireOpeningBalance,
                onChanged: (value) => _controller.updateQuickRules(
                    requireOpeningBalance: value),
              ),
              _switchTile(
                title: 'Auto Print Rekap Shift',
                subtitle: 'Cetak rekap otomatis saat shift ditutup.',
                value: state.autoPrintShiftRecap,
                onChanged: (value) =>
                    _controller.updateQuickRules(autoPrintShiftRecap: value),
              ),
              _switchTile(
                title: 'Izinkan Edit Saldo Akhir',
                subtitle:
                    'Kasir boleh mengubah hasil hitung kas fisik sebelum tutup shift.',
                value: state.allowEditActualCash,
                onChanged: (value) =>
                    _controller.updateQuickRules(allowEditActualCash: value),
              ),

              const SizedBox(height: 10),

              // ── Jadwal Shift ─────────────────────────────────────────────
              const _SectionLabel('Konfigurasi Jadwal Shift'),
              const SizedBox(height: 2),
              _switchTile(
                title: 'Aktifkan Pembatasan Jadwal Shift',
                subtitle:
                    'Jika aktif, hanya staf yang terdaftar di jadwal shift yang dapat membuka shift pada waktu tersebut.\n'
                    'Jika staf lain mencoba buka shift, akan muncul peringatan konfirmasi.',
                value: state.shiftScheduleEnabled,
                onChanged: (value) => _controller.updateShiftSchedule(
                    enabled: value),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: Colors.blue.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Jika jadwal shift tidak dikonfigurasi: siapapun yang login dan membuka shift '
                        'akan dianggap bertanggung jawab atas shift tersebut tanpa batasan.\n\n'
                        'Jika jadwal shift aktif: hanya staf terdaftar untuk slot waktu tersebut yang dapat '
                        'membuka shift tanpa peringatan.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ── Device Discipline ────────────────────────────────────────
              const _SectionLabel('Disiplin Perangkat'),
              const SizedBox(height: 2),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                        height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Transform.scale(
            scale: 0.75,
            child: Switch.adaptive(
              value: value, 
              onChanged: onChanged,
              activeTrackColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(List<_InfoRow> rows) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(row.label,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280))),
                    Text(row.value,
                        style: const TextStyle(
                            fontSize: 12,
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Row(
        children: [
          Container(
            width: 4, 
            height: 14, 
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary, 
              borderRadius: BorderRadius.circular(2)
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
                letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
}
