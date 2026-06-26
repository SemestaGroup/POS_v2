import 'package:flutter/material.dart';

import '../../../../../../l10n/app_localizations.dart';

class StaffRolesView extends StatelessWidget {
  const StaffRolesView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // ── Controls ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.staffRolesMenu,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1D2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kelola hak akses dan peran (role) staf aplikasi.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Tambah Peran'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey.shade100),

        // ── Content ───────────────────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildRoleCard(
                context: context,
                roleName: 'Pemilik (Owner)',
                userCount: 1,
                isDefault: true,
              ),
              const SizedBox(height: 16),
              _buildRoleCard(
                context: context,
                roleName: 'Supervisor',
                userCount: 2,
                isDefault: false,
              ),
              const SizedBox(height: 16),
              _buildRoleCard(
                context: context,
                roleName: 'Kasir',
                userCount: 5,
                isDefault: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String roleName,
    required int userCount,
    required bool isDefault,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.admin_panel_settings_rounded, color: primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      roleName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1D2E),
                      ),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Default',
                          style: TextStyle(fontSize: 10, color: primaryColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$userCount Akun terhubung',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.edit_outlined, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
