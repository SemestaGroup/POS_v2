import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../stores/staff_roles_store.dart';

class StaffRolesContent extends StatefulWidget {
  const StaffRolesContent({super.key});

  @override
  State<StaffRolesContent> createState() => _StaffRolesContentState();
}

class _StaffRolesContentState extends State<StaffRolesContent> {
  late StaffRolesStore _store;

  @override
  void initState() {
    super.initState();
    _store = StaffRolesStore();
    _store.fetchRoles();
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // ── Controls ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          color: Colors.white,
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
                'Daftar peran (role) staf aplikasi dan jumlah akun per peran.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey.shade100),

        // ── Content ───────────────────────────────────────────────────────
        Expanded(
          child: ValueListenableBuilder<bool>(
            valueListenable: _store.isLoading,
            builder: (context, isLoading, child) {
              if (isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              return ValueListenableBuilder<List<StaffRoleAggregate>>(
                valueListenable: _store.roles,
                builder: (context, roles, child) {
                  if (roles.isEmpty) {
                    return Center(
                      child: Text(
                        'Belum ada data peran staf',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: roles.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final role = roles[index];
                      return _buildRoleCard(
                        context: context,
                        roleName: role.roleName,
                        userCount: role.userCount,
                        isDefault: role.isDefault,
                      );
                    },
                  );
                },
              );
            },
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
            child: Icon(
              Icons.admin_panel_settings_rounded,
              color: primaryColor,
            ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Default',
                          style: TextStyle(
                            fontSize: 10,
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$userCount Akun terhubung',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
