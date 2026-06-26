import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../core/services/sync/pos_v2_sync_orchestrator.dart';
import '../../../core/services/sync/pos_v2_sync_status_store.dart';
import '../../../modules/sales/shared/models/pos_catalog_store.dart';
import '../../../modules/sales/shared/models/sales_order_store.dart';

class SyncBootstrapScreen extends StatefulWidget {
  const SyncBootstrapScreen({super.key});

  @override
  State<SyncBootstrapScreen> createState() => _SyncBootstrapScreenState();
}

class _SyncBootstrapScreenState extends State<SyncBootstrapScreen> {
  final PosV2SyncOrchestrator _syncOrchestrator = PosV2SyncOrchestrator();

  static const Color _primaryColor = Color(0xFF6366F1);
  static const Color _scaffoldBg = Color(0xFFF8FAFB);
  static const String _fontBold = 'popsem';
  static const String _fontMedium = 'popmed';
  static const String _fontRegular = 'popreg';

  bool _hasError = false;
  String _errorMessage = '';
  String _loadingStatus = '';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSync();
    });
  }

  Future<void> _startSync() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _hasError = false;
      _errorMessage = '';
      _loadingStatus = l10n.syncPreparingSettings;
      _progress = 0.05;
    });
    PosV2SyncStatusStore.instance.start(
      blocking: true,
      stage: 'settings',
      progress: 0.1,
    );

    try {
      final session = PosV2RuntimeSessionStore.instance.currentSession;
      if (session == null) {
        throw Exception('No active session found for sync.');
      }

      final syncContext = session.toSyncContext();

      await _syncOrchestrator.syncBootstrap(syncContext);
      if (!mounted) return;
      setState(() {
        _loadingStatus = l10n.syncPreparingShift;
        _progress = 0.15;
      });

      PosV2SyncStatusStore.instance.update(stage: 'shift', progress: 0.25);
      await _syncOrchestrator.syncActiveShiftForContext(syncContext);
      if (!mounted) return;
      setState(() {
        _loadingStatus = l10n.syncPreparingCategoriesBrands;
        _progress = 0.30;
      });

      PosV2SyncStatusStore.instance.update(
        stage: 'categories_brands',
        progress: 0.45,
      );
      await _syncOrchestrator.syncCategories(syncContext);
      await _syncOrchestrator.syncBrands(syncContext);
      if (!mounted) return;
      setState(() {
        _loadingStatus = l10n.syncPreparingCatalog;
        _progress = 0.45;
      });

      PosV2SyncStatusStore.instance.update(stage: 'catalog', progress: 0.72);
      await _syncOrchestrator.syncItemsPaged(
        syncContext,
        baseQuery: <String, dynamic>{'status': 'active'},
        itemPerPage: 1000,
        startPage: 1,
        maxPages: 5,
      );
      if (!mounted) return;
      setState(() => _progress = 0.70);

      await _syncOrchestrator.syncPromotions(
        syncContext,
        query: <String, dynamic>{
          'status': '1',
          if (syncContext.locationId.isNotEmpty)
            'id_location': syncContext.locationId,
        },
        allowNotFoundEmpty: true,
      );

      if (!mounted) return;
      setState(() {
        _loadingStatus = 'Memuat pesanan aktif...'; // Fetching active orders
        _progress = 0.80;
      });
      PosV2SyncStatusStore.instance.update(stage: 'orders', progress: 0.80);
      await _syncOrchestrator.syncOrders(
        syncContext,
        query: <String, dynamic>{'limit': 50, 'page': 1},
        pullDetails: true,
        detailLimit: 25,
      );

      if (!mounted) return;
      setState(() {
        _loadingStatus = l10n.syncPreparingLocalCache;
        _progress = 0.85;
      });

      PosV2SyncStatusStore.instance.update(
        stage: 'local_cache',
        progress: 0.92,
      );
      await PosCatalogStore.instance.refresh();
      await SalesOrderStore.instance.refreshFromPersistence();
      if (!mounted) return;
      setState(() => _progress = 0.92);

      // Precache product images so they appear instantly
      try {
        final products =
            PosCatalogStore.instance.snapshotNotifier.value.products;
        final imagesToPrecache = products
            .map((p) => p['image'] as String?)
            .where((url) => url != null && url.isNotEmpty)
            .take(30)
            .toList();

        await Future.wait(
          imagesToPrecache.map((url) async {
            try {
              final provider = CachedNetworkImageProvider(url!);
              await precacheImage(
                provider, 
                context,
                onError: (exception, stackTrace) {
                  // Silently ignore 404 or missing image errors during precaching
                  // so they don't spam the console.
                },
              );
            } catch (_) {}
          }),
        );
      } catch (_) {}

      if (!mounted) return;
      setState(() => _progress = 1.0);

      await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
      PosV2SyncStatusStore.instance.succeed(stage: 'ready');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
      PosV2SyncStatusStore.instance.fail(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final percentText = '${(_progress * 100).toInt()}%';

    return Scaffold(
      backgroundColor: _scaffoldBg,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _primaryColor.withOpacity(0.05),
              _scaffoldBg,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Sync icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primaryColor.withOpacity(0.10),
              ),
              child: const Icon(
                CupertinoIcons.arrow_2_circlepath,
                size: 64,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 32),

            // Title
            const Text(
              'Synchronizing Data',
              style: TextStyle(
                fontFamily: _fontBold,
                fontSize: 28,
                color: Color(0xFF1A1A2E),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),

            // Subtitle
            Text(
              'Please wait while we prepare your workspace\nConnecting to secure server...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: _fontRegular,
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),

            if (_hasError) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Color(0xFFEF4444), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${l10n.syncPreparingError}\n$_errorMessage',
                              style: const TextStyle(
                                fontFamily: _fontRegular,
                                fontSize: 12,
                                color: Color(0xFFB91C1C),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _startSync,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text(
                            l10n.retryAction,
                            style: const TextStyle(
                              fontFamily: _fontBold,
                              fontSize: 13,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Progress section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 64),
                child: Column(
                  children: [
                    // Status + percentage row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _loadingStatus,
                            style: const TextStyle(
                              fontFamily: _fontMedium,
                              fontSize: 12,
                              color: _primaryColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          percentText,
                          style: const TextStyle(
                            fontFamily: _fontBold,
                            fontSize: 12,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          _primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Text(
                'Offline Mode will be available after sync',
                style: TextStyle(
                  fontFamily: _fontRegular,
                  fontSize: 11,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
