import 'package:flutter/material.dart';

import '../../../stores/register_provisioning_store.dart';

class DeviceStatusView extends StatefulWidget {
  const DeviceStatusView({super.key});

  @override
  State<DeviceStatusView> createState() => _DeviceStatusViewState();
}

class _DeviceStatusViewState extends State<DeviceStatusView> {
  final RegisterProvisioningStore _store = RegisterProvisioningStore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _store.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = _DeviceStatusStrings.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return ValueListenableBuilder<RegisterProvisioningSnapshot>(
      valueListenable: _store.snapshotNotifier,
      builder: (context, snapshot, _) {
        final session = snapshot.session;
        return Container(
          color: const Color(0xFFF8FAFC),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strings.subtitle,
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: snapshot.isLoading ? null : () => _store.refresh(),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(strings.refresh),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: snapshot.isSaving || session == null
                          ? null
                          : () => _openRegisterDialog(context, null, snapshot),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(strings.newRegister),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (snapshot.errorMessage != null && snapshot.errorMessage!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  child: _InlineMessage(
                    message: snapshot.errorMessage!,
                    tone: _InlineMessageTone.error,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _StatusCard(
                        title: strings.currentDevice,
                        accentColor: primary,
                        child: session == null
                            ? Text(
                                strings.noSession,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _MetaPill(
                                        icon: Icons.devices_rounded,
                                        label:
                                            '${strings.deviceId}: ${session.deviceId ?? '-'}',
                                      ),
                                      _MetaPill(
                                        icon: Icons.point_of_sale_rounded,
                                        label:
                                            '${strings.registerId}: ${session.registerId ?? strings.unassigned}',
                                        highlighted: (session.registerId ?? '')
                                            .trim()
                                            .isNotEmpty,
                                      ),
                                      _MetaPill(
                                        icon: Icons.place_outlined,
                                        label:
                                            '${strings.locationId}: ${session.locationId.isEmpty ? '-' : session.locationId}',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    session.staffFullName ??
                                        session.staffEmail ??
                                        strings.noSession,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    session.baseUrl,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      FilledButton.tonal(
                                        onPressed: snapshot.isSaving
                                            ? null
                                            : () => _store.assignCurrentDeviceRegister(null),
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size(0, 34),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                        child: Text(strings.clearAssignment),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatusCard(
                        title: strings.provisioningNotes,
                        accentColor: const Color(0xFF7C3AED),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.noteOne,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              strings.noteTwo,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              strings.noteThree,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: snapshot.isLoading && snapshot.registers.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : snapshot.registers.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    strings.emptyRegisters,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.5,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: snapshot.registers.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final register = snapshot.registers[index];
                                  final isAssigned =
                                      snapshot.currentRegisterId == register.registerId;
                                  return _RegisterTile(
                                    strings: strings,
                                    register: register,
                                    isAssigned: isAssigned,
                                    isBusy: snapshot.isSaving,
                                    onAssign: register.isActive
                                        ? () => _store.assignCurrentDeviceRegister(
                                              register.registerId,
                                            )
                                        : null,
                                    onEdit: () =>
                                        _openRegisterDialog(context, register, snapshot),
                                    onDelete: () =>
                                        _confirmDelete(context, register, strings),
                                  );
                                },
                              ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openRegisterDialog(
    BuildContext context,
    RegisterProvisioningRecord? record,
    RegisterProvisioningSnapshot snapshot,
  ) async {
    final strings = _DeviceStatusStrings.of(context);
    final session = snapshot.session;
    if (session == null) {
      return;
    }

    final locationController = TextEditingController(
      text: record?.locationId ?? session.locationId,
    );
    final registerIdController = TextEditingController(
      text: record?.registerId ?? '',
    );
    final registerNameController = TextEditingController(
      text: record?.registerName ?? '',
    );
    final deviceHintController = TextEditingController(
      text: record?.deviceIdHint ?? session.deviceId ?? '',
    );
    final notesController = TextEditingController(text: record?.notes ?? '');
    var isActive = record?.isActive ?? true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              title: Text(
                record == null ? strings.newRegister : strings.editRegister,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _compactField(
                        controller: locationController,
                        label: strings.locationId,
                        enabled: record == null,
                      ),
                      const SizedBox(height: 10),
                      _compactField(
                        controller: registerIdController,
                        label: strings.registerId,
                      ),
                      const SizedBox(height: 10),
                      _compactField(
                        controller: registerNameController,
                        label: strings.registerName,
                      ),
                      const SizedBox(height: 10),
                      _compactField(
                        controller: deviceHintController,
                        label: strings.deviceHint,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notesController,
                        minLines: 2,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          labelText: strings.notes,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        value: isActive,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          strings.activeLabel,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onChanged: (value) => setDialogState(() => isActive = value),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(strings.cancel),
                ),
                FilledButton(
                  onPressed: () async {
                    final locationId = locationController.text.trim();
                    final registerId = registerIdController.text.trim();
                    final registerName = registerNameController.text.trim();
                    if (locationId.isEmpty ||
                        registerId.isEmpty ||
                        registerName.isEmpty) {
                      return;
                    }

                    try {
                      if (record == null) {
                        await _store.createRegister(
                          locationId: locationId,
                          registerId: registerId,
                          registerName: registerName,
                          deviceIdHint: deviceHintController.text.trim(),
                          notes: notesController.text.trim(),
                          isActive: isActive,
                        );
                      } else {
                        await _store.updateRegister(
                          id: record.id,
                          locationId: locationId,
                          registerId: registerId,
                          registerName: registerName,
                          deviceIdHint: deviceHintController.text.trim(),
                          notes: notesController.text.trim(),
                          isActive: isActive,
                        );
                      }
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    } catch (_) {}
                  },
                  child: Text(strings.save),
                ),
              ],
            );
          },
        );
      },
    );

    locationController.dispose();
    registerIdController.dispose();
    registerNameController.dispose();
    deviceHintController.dispose();
    notesController.dispose();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    RegisterProvisioningRecord record,
    _DeviceStatusStrings strings,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(strings.deleteRegister),
        content: Text(
          strings.deleteRegisterPrompt(record.registerName, record.registerId),
          style: const TextStyle(fontSize: 12, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.deleteLabel),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _store.deleteRegister(record.id);
      } catch (_) {}
    }
  }

  Widget _compactField({
    required TextEditingController controller,
    required String label,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.child,
    required this.accentColor,
  });

  final String title;
  final Widget child;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _RegisterTile extends StatelessWidget {
  const _RegisterTile({
    required this.strings,
    required this.register,
    required this.isAssigned,
    required this.isBusy,
    required this.onAssign,
    required this.onEdit,
    required this.onDelete,
  });

  final _DeviceStatusStrings strings;
  final RegisterProvisioningRecord register;
  final bool isAssigned;
  final bool isBusy;
  final VoidCallback? onAssign;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAssigned ? const Color(0xFFF5F3FF) : const Color(0xFFFCFCFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAssigned ? const Color(0xFFC4B5FD) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      register.registerName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    _StateBadge(
                      label: register.isActive
                          ? strings.activeLabel
                          : strings.inactiveLabel,
                      color: register.isActive
                          ? const Color(0xFF0F766E)
                          : const Color(0xFF9CA3AF),
                      background: register.isActive
                          ? const Color(0xFFCCFBF1)
                          : const Color(0xFFF3F4F6),
                    ),
                    if (isAssigned)
                      _StateBadge(
                        label: strings.assignedLabel,
                        color: const Color(0xFF6D28D9),
                        background: const Color(0xFFEDE9FE),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${strings.registerId}: ${register.registerId}  •  ${strings.locationId}: ${register.locationId}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
                if ((register.deviceIdHint ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${strings.deviceHint}: ${register.deviceIdHint}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
                if ((register.notes ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    register.notes!,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              FilledButton.tonal(
                onPressed: isBusy ? null : onAssign,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                child: Text(strings.assignHere),
              ),
              OutlinedButton(
                onPressed: isBusy ? null : onEdit,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                child: Text(strings.editLabel),
              ),
              OutlinedButton(
                onPressed: isBusy ? null : onDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB91C1C),
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                child: Text(strings.deleteLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
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
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFEDE9FE) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted ? const Color(0xFFC4B5FD) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6B7280)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}

enum _InlineMessageTone { error }

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message, required this.tone});

  final String message;
  final _InlineMessageTone tone;

  @override
  Widget build(BuildContext context) {
    final color = tone == _InlineMessageTone.error
        ? const Color(0xFFB91C1C)
        : const Color(0xFF374151);
    final background = tone == _InlineMessageTone.error
        ? const Color(0xFFFEF2F2)
        : const Color(0xFFF3F4F6);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 11, height: 1.45, color: color),
      ),
    );
  }
}

class _DeviceStatusStrings {
  const _DeviceStatusStrings({required this.isIndonesian});

  final bool isIndonesian;

  static _DeviceStatusStrings of(BuildContext context) {
    return _DeviceStatusStrings(
      isIndonesian: Localizations.localeOf(context).languageCode == 'id',
    );
  }

  String get title =>
      isIndonesian ? 'Register & Device Provisioning' : 'Register & Device Provisioning';
  String get subtitle => isIndonesian
      ? 'Kelola register kasir terpisah dari device, lalu tetapkan device ini ke register yang aktif.'
      : 'Manage cashier registers separately from devices, then assign this device to the active register.';
  String get refresh => isIndonesian ? 'Refresh' : 'Refresh';
  String get newRegister => isIndonesian ? 'Register Baru' : 'New Register';
  String get currentDevice => isIndonesian ? 'Device Saat Ini' : 'Current Device';
  String get provisioningNotes => isIndonesian ? 'Catatan Alur' : 'Flow Notes';
  String get noteOne => isIndonesian
      ? 'Setiap register mewakili titik kasir yang bertanggung jawab atas shift dan order.'
      : 'Each register represents a cashier station responsible for shifts and orders.';
  String get noteTwo => isIndonesian
      ? 'Dalam fase transisi, register masih boleh sama dengan device ID, tetapi target akhirnya adalah provisioning terpisah.'
      : 'During the transition phase, a register may still match the device ID, but the long-term target is separate provisioning.';
  String get noteThree => isIndonesian
      ? 'Gunakan satu register aktif per terminal agar audit shift, order, dan approval tetap jelas.'
      : 'Use one active register per terminal so shift, order, and approval audit trails stay clear.';
  String get noSession => isIndonesian ? 'Belum ada sesi aktif.' : 'No active session yet.';
  String get deviceId => isIndonesian ? 'Device ID' : 'Device ID';
  String get registerId => isIndonesian ? 'Register ID' : 'Register ID';
  String get registerName => isIndonesian ? 'Nama Register' : 'Register Name';
  String get locationId => isIndonesian ? 'Location' : 'Location';
  String get unassigned => isIndonesian ? 'Belum dipasang' : 'Unassigned';
  String get clearAssignment =>
      isIndonesian ? 'Lepas Register Dari Device Ini' : 'Clear Assignment';
  String get emptyRegisters => isIndonesian
      ? 'Belum ada register yang diprovision untuk lokasi ini. Buat register baru terlebih dahulu.'
      : 'No provisioned registers exist for this location yet. Create a register first.';
  String get activeLabel => isIndonesian ? 'Aktif' : 'Active';
  String get inactiveLabel => isIndonesian ? 'Nonaktif' : 'Inactive';
  String get assignedLabel => isIndonesian ? 'Dipakai Device Ini' : 'Assigned Here';
  String get assignHere => isIndonesian ? 'Pakai di Device Ini' : 'Assign Here';
  String get editLabel => isIndonesian ? 'Edit' : 'Edit';
  String get deleteLabel => isIndonesian ? 'Hapus' : 'Delete';
  String get deleteRegister => isIndonesian ? 'Hapus Register' : 'Delete Register';
  String deleteRegisterPrompt(String name, String id) => isIndonesian
      ? 'Hapus register "$name" ($id)? Tindakan ini tidak bisa dibatalkan.'
      : 'Delete register "$name" ($id)? This action cannot be undone.';
  String get newRegisterTitle => isIndonesian ? 'Register Baru' : 'New Register';
  String get editRegister => isIndonesian ? 'Edit Register' : 'Edit Register';
  String get save => isIndonesian ? 'Simpan' : 'Save';
  String get cancel => isIndonesian ? 'Batal' : 'Cancel';
  String get deviceHint => isIndonesian ? 'Hint Device ID' : 'Device ID Hint';
  String get notes => isIndonesian ? 'Catatan' : 'Notes';
}
