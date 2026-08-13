import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../../../../core/services/sync/wa_report_request_service.dart';

class WaReportType {
  const WaReportType({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
}

class WaReportRequestData {
  const WaReportRequestData({
    required this.reportTypes,
    required this.selectedReportId,
    required this.qrPayload,
    required this.locationLabel,
    required this.isLoading,
    required this.hasGeneratedInSession,
    required this.secondsRemaining,
    required this.onSelectReport,
    required this.onGenerateQr,
    required this.onResetQr,
  });

  final List<WaReportType> reportTypes;
  final String selectedReportId;
  final String? qrPayload;
  final String? locationLabel;
  final bool isLoading;
  final bool hasGeneratedInSession;
  final int secondsRemaining;
  final ValueChanged<String> onSelectReport;
  final VoidCallback onGenerateQr;
  final VoidCallback onResetQr;

  WaReportType get currentReportType =>
      reportTypes.firstWhere((t) => t.id == selectedReportId);

  String get formattedTimer {
    final m = secondsRemaining ~/ 60;
    final s = secondsRemaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get progress =>
      secondsRemaining / WaReportRequestService.qrDuration.inSeconds;
}

class WaReportRequestContent extends StatefulWidget {
  const WaReportRequestContent({
    super.key,
    required this.builder,
    this.service,
  });

  final Widget Function(BuildContext context, WaReportRequestData data) builder;
  final WaReportRequestService? service;

  @override
  State<WaReportRequestContent> createState() => _WaReportRequestContentState();
}

class _WaReportRequestContentState extends State<WaReportRequestContent> {
  final List<WaReportType> _reportTypes = const [
    WaReportType(
      id: 'OMZET 3 JAM',
      label: 'Omzet 3 Jam',
      description: 'Ringkasan omzet & penjualan 3 jam terakhir',
      icon: Icons.access_time_rounded,
    ),
    WaReportType(
      id: 'OMZET DAILY',
      label: 'Omzet Harian',
      description: 'Akumulasi total omzet harian toko hari ini',
      icon: Icons.calendar_today_rounded,
    ),
  ];

  late String _selectedReportId;
  String? _qrPayload;
  String? _locationLabel;
  bool _isLoading = false;
  bool _hasGeneratedInSession = false;
  bool _hasIssuedAuthKey = false;
  bool _isRevokingAuthKey = false;

  Timer? _timer;
  int _secondsRemaining = 0;

  WaReportRequestService get _service =>
      widget.service ?? WaReportRequestService.instance;

  @override
  void initState() {
    super.initState();
    _selectedReportId = _reportTypes.first.id;
    _initSessionInfo();
  }

  Future<void> _initSessionInfo() async {
    final session =
        PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    if (mounted) {
      setState(() {
        _locationLabel = session?.locationId.trim();
      });
    }
  }

  @override
  void dispose() {
    _cancelTimer();
    unawaited(_revokeAuthKey());
    super.dispose();
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _startTimer() {
    _cancelTimer();
    _secondsRemaining = WaReportRequestService.qrDuration.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        _handleTimerExpired();
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  void _handleTimerExpired() {
    _cancelTimer();
    setState(() {
      _secondsRemaining = 0;
      _qrPayload = null;
    });
    unawaited(_revokeAuthKey());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Kunci QR telah kadaluwarsa (5 menit).',
            style: TextStyle(height: 1.3),
          ),
          backgroundColor: const Color(0xFFEA580C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _generateQrCode() async {
    if (_isLoading || _hasGeneratedInSession) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final session =
          PosV2RuntimeSessionStore.instance.currentSession ??
          await PosV2RuntimeSessionStore.instance.restoreFromDatabase();

      final loc = session?.locationId.trim() ?? '';
      if (loc.isEmpty) {
        throw const WaReportRequestException(
          'ID lokasi tenant tidak ditemukan. Silakan masuk ulang ke POS.',
        );
      }

      final authKey = await _service.generateAuthKey();
      final payload = _service.buildWaPayload(
        location: loc,
        authKey: authKey,
        requestType: _selectedReportId,
      );

      _hasGeneratedInSession = true;
      _hasIssuedAuthKey = true;
      if (mounted) {
        setState(() {
          _locationLabel = loc;
          _qrPayload = payload;
          _isLoading = false;
        });
        _startTimer();
      } else {
        unawaited(_revokeAuthKey());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal membuat QR: $e',
              style: const TextStyle(height: 1.3),
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _resetQrCode() {
    _cancelTimer();
    setState(() {
      _secondsRemaining = 0;
      _qrPayload = null;
    });
    unawaited(_revokeAuthKey());
  }

  Future<void> _revokeAuthKey() async {
    if (!_hasIssuedAuthKey || _isRevokingAuthKey) {
      return;
    }
    _hasIssuedAuthKey = false;
    _isRevokingAuthKey = true;
    try {
      await _service.revokeAuthKey();
    } finally {
      _isRevokingAuthKey = false;
    }
  }

  void _onSelectReport(String id) {
    if (!_hasGeneratedInSession && _selectedReportId != id) {
      setState(() {
        _selectedReportId = id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = WaReportRequestData(
      reportTypes: _reportTypes,
      selectedReportId: _selectedReportId,
      qrPayload: _qrPayload,
      locationLabel: _locationLabel,
      isLoading: _isLoading,
      hasGeneratedInSession: _hasGeneratedInSession,
      secondsRemaining: _secondsRemaining,
      onSelectReport: _onSelectReport,
      onGenerateQr: _generateQrCode,
      onResetQr: _resetQrCode,
    );

    return widget.builder(context, data);
  }
}
