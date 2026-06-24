import 'package:flutter/material.dart';

import '../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../l10n/app_localizations.dart';
import '../../operations/shift/models/active_shift_store.dart';

class ShiftGateScreen extends StatefulWidget {
  const ShiftGateScreen({super.key});

  @override
  State<ShiftGateScreen> createState() => _ShiftGateScreenState();
}

class _ShiftGateScreenState extends State<ShiftGateScreen> {
  final _shiftNameController = TextEditingController(text: 'Main Shift');
  final _openingBalanceController = TextEditingController(text: '0');
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _shiftNameController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  Future<void> _openShift() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isSubmitting) {
      return;
    }

    final shiftName = _shiftNameController.text.trim();
    final openingBalance = int.tryParse(
      _openingBalanceController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );

    if (shiftName.isEmpty || openingBalance == null) {
      setState(() {
        _errorMessage = l10n.shiftGateIncomplete;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ActiveShiftStore.instance.openShift(
        shiftName: shiftName,
        openingBalance: openingBalance,
      );
    } catch (error) {
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final session = PosV2RuntimeSessionStore.instance.currentSession;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 0,
            margin: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.point_of_sale_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.shiftGateTitle,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.shiftGateSubtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (session != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.staffFullName ?? session.staffEmail ?? '-',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${l10n.deviceIdLabel}: ${session.deviceId ?? '-'}',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${l10n.locationLabel}: ${session.locationId}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _shiftNameController,
                    decoration: InputDecoration(labelText: l10n.shiftNameLabel),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _openingBalanceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.openingBalanceLabel,
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _openShift,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.openShiftAction),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
