import 'package:flutter/material.dart';

import '../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../../l10n/app_localizations.dart';
import 'merchant_login/tablet_landscape/view.dart';
import 'merchant_login/mobile_portrait/view.dart';

/// Wrapper widget that allows switching between tablet and smartphone
/// login layouts. By default it detects the layout from the screen size,
/// but the user can manually toggle via a button.
class MerchantLoginWrapper extends StatefulWidget {
  const MerchantLoginWrapper({super.key});

  @override
  State<MerchantLoginWrapper> createState() => _MerchantLoginWrapperState();
}

class _MerchantLoginWrapperState extends State<MerchantLoginWrapper> {
  /// null means "auto-detect based on screen width"
  bool? _forceTabletLayout;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (PosV2RuntimeSessionStore.instance.wasForcedOut) {
        PosV2RuntimeSessionStore.instance.wasForcedOut = false;
        _showForcedOutDialog();
      }
    });
  }

  void _showForcedOutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final loc = AppLocalizations.of(context)!;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Colors.orange,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          loc.authForcedOutTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    loc.authForcedOutMessage,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      height: 38,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          loc.authForcedOutUnderstand,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _toggleLayout() {
    final isCurrentlyTablet = _forceTabletLayout ??
        MediaQuery.of(context).size.width >= 600;
    setState(() {
      _forceTabletLayout = !isCurrentlyTablet;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final useTabletLayout = _forceTabletLayout ?? (screenWidth >= 600);

    if (useTabletLayout) {
      return MerchantLoginTabletView(onToggleLayout: _toggleLayout);
    } else {
      return MerchantLoginMobileView(onToggleLayout: _toggleLayout);
    }
  }
}
