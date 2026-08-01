import 'package:flutter/material.dart';
import '../../../../../../../../core/widgets/responsive/responsive_context.dart';

import '../../controllers/profile_settings_controller.dart';
import '../../models/profile_settings_state.dart';

class ProfileSettingsContent extends StatefulWidget {
  const ProfileSettingsContent({super.key});

  @override
  State<ProfileSettingsContent> createState() => _ProfileSettingsContentState();
}

class _ProfileSettingsContentState extends State<ProfileSettingsContent> {
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
    final isMobile = context.isMobile;

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
        final avatarChar =
            (session?.staffFullName ?? session?.staffEmail ?? '?')
                .trim()
                .characters
                .first
                .toUpperCase();

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 14 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                'Profile Settings',
                'Identity and current device session',
              ),
              const SizedBox(height: 14),
              isMobile
                  ? _card(
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                avatarChar,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            session?.staffFullName ?? '-',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            session?.staffEmail ?? '-',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _pill(state.roleLabel ?? '-', primary),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: FilledButton.icon(
                              onPressed: state.isLoggingOut
                                  ? null
                                  : () async {
                                      try {
                                        await _controller.logoutCurrentDevice();
                                      } catch (_) {}
                                    },
                              icon: state.isLoggingOut
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.logout_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                              label: const Text(
                                'Logout Session',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _card(
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
                                avatarChar,
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.logout_rounded, size: 16),
                            label: const Text(
                              'Logout',
                              style: TextStyle(fontSize: 11),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
              const SizedBox(height: 14),
              _card(
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _metaTile(
                            'Tenant',
                            session?.tenantName ?? '-',
                            isMobile: true,
                          ),
                          const Divider(height: 20, color: Color(0xFFF3F4F6)),
                          _metaTile(
                            'Location',
                            session?.locationId ?? '-',
                            isMobile: true,
                          ),
                          const Divider(height: 20, color: Color(0xFFF3F4F6)),
                          _metaTile(
                            'Register',
                            session?.registerId ?? '-',
                            isMobile: true,
                          ),
                          const Divider(height: 20, color: Color(0xFFF3F4F6)),
                          _metaTile(
                            'Device',
                            session?.deviceId ?? '-',
                            isMobile: true,
                          ),
                          const Divider(height: 20, color: Color(0xFFF3F4F6)),
                          _metaTile(
                            'Base URL',
                            session?.baseUrl ?? '-',
                            isMobile: true,
                          ),
                        ],
                      )
                    : Wrap(
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
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _metaTile(String label, String value, {bool isMobile = false}) {
    return SizedBox(
      width: isMobile ? double.infinity : 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
