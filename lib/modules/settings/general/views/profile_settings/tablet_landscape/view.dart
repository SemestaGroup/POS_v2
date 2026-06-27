import 'package:flutter/material.dart';

import '../../../controllers/profile_settings_controller.dart';
import '../../../models/profile_settings_state.dart';

class ProfileSettingsView extends StatefulWidget {
  const ProfileSettingsView({super.key});

  @override
  State<ProfileSettingsView> createState() => _ProfileSettingsViewState();
}

class _ProfileSettingsViewState extends State<ProfileSettingsView> {
  final ProfileSettingsController _controller =
      ProfileSettingsController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return ValueListenableBuilder<ProfileSettingsState>(
      valueListenable: _controller.stateNotifier,
      builder: (context, state, _) {
        if (state.isLoading && state.session == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.errorMessage != null && state.session == null) {
          return Center(
            child: Text(
              state.errorMessage!,
              style: TextStyle(color: Colors.red.shade600),
            ),
          );
        }

        final session = state.session;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Profile Settings', 'Identity and current device session'),
              const SizedBox(height: 14),
              _card(
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          (session?.staffFullName ?? session?.staffEmail ?? '?')
                              .trim()
                              .characters
                              .first
                              .toUpperCase(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session?.staffFullName ?? '-',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            session?.staffEmail ?? '-',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 6),
                          _pill(state.roleLabel ?? '-', primary),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: state.isLoggingOut
                          ? null
                          : () async {
                              try {
                                await _controller.logoutCurrentDevice();
                              } catch (_) {}
                            },
                      icon: state.isLoggingOut
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.logout_rounded, size: 16),
                      label: const Text('Logout', style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _card(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _metaTile('Tenant', session?.tenantName ?? '-'),
                    _metaTile('Location', session?.locationId ?? '-'),
                    _metaTile('Register', session?.registerId ?? '-'),
                    _metaTile('Device', session?.deviceId ?? '-'),
                    _metaTile('Base URL', session?.baseUrl ?? '-'),
                  ],
                ),
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.errorMessage!,
                  style: TextStyle(fontSize: 11, color: Colors.red.shade600),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _metaTile(String label, String value) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
