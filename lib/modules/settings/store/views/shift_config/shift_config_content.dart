import 'package:flutter/material.dart';
import '../../controllers/store_settings_controller.dart';
import '../../models/store_settings_state.dart';

class ShiftConfigContent extends StatefulWidget {
  const ShiftConfigContent({required this.isMobile, super.key});

  final bool isMobile;

  @override
  State<ShiftConfigContent> createState() => _ShiftConfigContentState();
}

class _ShiftConfigContentState extends State<ShiftConfigContent> {
  final ShiftConfigController _controller = ShiftConfigController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.refresh();
    });
  }

  Widget _buildGroupedCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = widget.isMobile;

    return ValueListenableBuilder<ShiftConfigState>(
      valueListenable: _controller.stateNotifier,
      builder: (context, state, _) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final cashRules = [
          _switchTile(
            title: 'Wajibkan Modal Awal',
            subtitle: 'Kasir wajib memasukkan saldo awal saat buka shift.',
            value: state.requireOpeningBalance,
            onChanged: (value) =>
                _controller.updateQuickRules(requireOpeningBalance: value),
            isMobile: isMobile,
          ),
          _switchTile(
            title: 'Auto Print Rekap Shift',
            subtitle: 'Cetak rekap otomatis saat shift ditutup.',
            value: state.autoPrintShiftRecap,
            onChanged: (value) =>
                _controller.updateQuickRules(autoPrintShiftRecap: value),
            isMobile: isMobile,
          ),
          _switchTile(
            title: 'Izinkan Edit Saldo Akhir',
            subtitle:
                'Kasir boleh mengubah hasil hitung kas fisik sebelum tutup shift.',
            value: state.allowEditActualCash,
            onChanged: (value) =>
                _controller.updateQuickRules(allowEditActualCash: value),
            isMobile: isMobile,
          ),
        ];

        final scheduleRules = [
          _switchTile(
            title: 'Aktifkan Pembatasan Jadwal Shift',
            subtitle:
                'Jika aktif, hanya staf yang terdaftar di jadwal shift yang dapat membuka shift pada waktu tersebut.',
            value: state.shiftScheduleEnabled,
            onChanged: (value) =>
                _controller.updateShiftSchedule(enabled: value),
            isMobile: isMobile,
          ),
        ];

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Header
              Text(
                'Aturan Kas & Operasional Shift',
                style: TextStyle(
                  fontSize: isMobile ? 15 : 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sesuaikan kedisiplinan pembukaan shift, pencatatan laci kas, serta verifikasi otentikasi perangkat kasir.',
                style: TextStyle(
                  fontSize: isMobile ? 11 : 12,
                  color: const Color(0xFF4B5563),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Group 1: Cash & Shift rules
              const _GroupTitle(title: 'Operasional Kasir'),
              const SizedBox(height: 8),
              _buildGroupedCard(
                child: Column(
                  children: [
                    cashRules[0],
                    const Divider(
                      height: 1,
                      color: Color(0xFFF3F4F6),
                      indent: 16,
                      endIndent: 16,
                    ),
                    cashRules[1],
                    const Divider(
                      height: 1,
                      color: Color(0xFFF3F4F6),
                      indent: 16,
                      endIndent: 16,
                    ),
                    cashRules[2],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Group 2: Schedule rules
              const _GroupTitle(title: 'Pembatasan & Jadwal'),
              const SizedBox(height: 8),
              _buildGroupedCard(child: scheduleRules[0]),
              const SizedBox(height: 12),
              // Schedule Warning Info Panel (Clean & SaaS style)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Jika jadwal tidak aktif, seluruh staf dapat membuka shift secara bebas.\n'
                        'Jika jadwal aktif, verifikasi jadwal akan dilakukan saat buka shift.',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Group 3: Device Discipline (Clean Key-Value Status Rows)
              const _GroupTitle(title: 'Keamanan & Autentikasi Perangkat'),
              const SizedBox(height: 8),
              _buildGroupedCard(
                child: Column(
                  children: [
                    _infoRowTile(
                      title: 'Satu Perangkat per Staf',
                      subtitle:
                          'Membatasi staf hanya login di satu device terdaftar.',
                      value: state.enforceSingleDevicePerStaff,
                    ),
                    const Divider(
                      height: 1,
                      color: Color(0xFFF3F4F6),
                      indent: 16,
                      endIndent: 16,
                    ),
                    _infoRowTile(
                      title: 'Wajib Device ID Terverifikasi',
                      subtitle:
                          'Perangkat kasir wajib terdaftar di database pusat.',
                      value: state.requireDeviceId,
                    ),
                    const Divider(
                      height: 1,
                      color: Color(0xFFF3F4F6),
                      indent: 16,
                      endIndent: 16,
                    ),
                    _infoRowTile(
                      title: 'Fitur Self-Order Aktif',
                      subtitle: 'Mengizinkan pemesanan mandiri oleh pelanggan.',
                      value: state.selfOrderEnabled,
                    ),
                    const Divider(
                      height: 1,
                      color: Color(0xFFF3F4F6),
                      indent: 16,
                      endIndent: 16,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Mode Operasional Perangkat',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Konfigurasi mode kerja pos saat ini.',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              state.operatingMode,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (state.errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
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
    bool isMobile = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Transform.scale(
            scale: 0.8,
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

  Widget _infoRowTile({
    required String title,
    required String subtitle,
    required bool value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            value ? 'Aktif' : 'Nonaktif',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: value ? const Color(0xFF16A34A) : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  final String title;
  const _GroupTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2.0, bottom: 2.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4B5563),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
