import 'dart:io';

import 'package:blue_thermal_printer/blue_thermal_printer.dart' as blue;
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';

import '../../../modules/settings/printers/models/printer_settings_models.dart';
import '../models/printer_render_models.dart';

abstract class PrinterTransportAdapter {
  const PrinterTransportAdapter();

  String get channel;

  bool supports(PrinterDeviceConfig printer);

  Future<PrinterDispatchResult> dispatch(
    PrinterDeviceConfig printer,
    PrinterRenderOutput output,
  );
}

class SystemPrintAdapter extends PrinterTransportAdapter {
  const SystemPrintAdapter();

  @override
  String get channel => 'system';

  @override
  bool supports(PrinterDeviceConfig printer) => true;

  @override
  Future<PrinterDispatchResult> dispatch(
    PrinterDeviceConfig printer,
    PrinterRenderOutput output,
  ) async {
    await Printing.layoutPdf(
      onLayout: (_) async => Uint8List.fromList(output.pdfBytes),
      name: '${printer.displayName}-${output.documentType.name}',
    );
    return const PrinterDispatchResult(success: true, channel: 'system');
  }
}

class NetworkRawPrintAdapter extends PrinterTransportAdapter {
  const NetworkRawPrintAdapter();

  @override
  String get channel => 'network';

  @override
  bool supports(PrinterDeviceConfig printer) =>
      printer.connectionType == 'network' &&
      (printer.connectionTarget ?? '').trim().isNotEmpty &&
      !kIsWeb;

  @override
  Future<PrinterDispatchResult> dispatch(
    PrinterDeviceConfig printer,
    PrinterRenderOutput output,
  ) async {
    final target = (printer.connectionTarget ?? '').trim();
    if (target.isEmpty) {
      return const PrinterDispatchResult(
        success: false,
        channel: 'network',
        message: 'Missing network printer target.',
      );
    }
    Socket? socket;
    try {
      socket = await Socket.connect(
        target,
        printer.networkPort,
        timeout: const Duration(seconds: 4),
      );
      socket.add(output.rawBytes);
      await socket.flush();
      await socket.close();
      return const PrinterDispatchResult(success: true, channel: 'network');
    } catch (error) {
      try {
        socket?.destroy();
      } catch (_) {}
      return PrinterDispatchResult(
        success: false,
        channel: 'network',
        message: error.toString(),
      );
    }
  }
}

class BluetoothRawPrintAdapter extends PrinterTransportAdapter {
  const BluetoothRawPrintAdapter();

  @override
  String get channel => 'bluetooth';

  @override
  bool supports(PrinterDeviceConfig printer) =>
      printer.connectionType == 'bluetooth' &&
      (printer.connectionTarget ?? '').trim().isNotEmpty &&
      !kIsWeb;

  @override
  Future<PrinterDispatchResult> dispatch(
    PrinterDeviceConfig printer,
    PrinterRenderOutput output,
  ) async {
    final targetAddress = (printer.connectionTarget ?? '').trim();
    if (targetAddress.isEmpty) {
      return const PrinterDispatchResult(
        success: false,
        channel: 'bluetooth',
        message: 'Missing bluetooth printer address.',
      );
    }
    final bluetooth = blue.BlueThermalPrinter.instance;
    try {
      final bonded = await bluetooth.getBondedDevices();
      blue.BluetoothDevice? target;
      for (final device in bonded) {
        if (device.address == targetAddress) {
          target = device;
          break;
        }
      }
      if (target == null) {
        return const PrinterDispatchResult(
          success: false,
          channel: 'bluetooth',
          message: 'Bluetooth device not found in bonded devices.',
        );
      }
      try {
        await bluetooth.disconnect();
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await bluetooth.connect(target);
      final connected = await bluetooth.isConnected;
      if (connected != true) {
        return const PrinterDispatchResult(
          success: false,
          channel: 'bluetooth',
          message: 'Bluetooth printer did not confirm connection.',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await bluetooth.writeBytes(Uint8List.fromList(output.rawBytes));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      try {
        await bluetooth.disconnect();
      } catch (_) {}
      return const PrinterDispatchResult(success: true, channel: 'bluetooth');
    } catch (error) {
      try {
        await bluetooth.disconnect();
      } catch (_) {}
      return PrinterDispatchResult(
        success: false,
        channel: 'bluetooth',
        message: error.toString(),
      );
    }
  }
}

class PrinterTransportService {
  PrinterTransportService._();

  static final PrinterTransportService instance = PrinterTransportService._();

  final List<PrinterTransportAdapter> _adapters = const <PrinterTransportAdapter>[
    NetworkRawPrintAdapter(),
    BluetoothRawPrintAdapter(),
    SystemPrintAdapter(),
  ];

  Future<PrinterDispatchResult> dispatch(
    PrinterDeviceConfig printer,
    PrinterRenderOutput output,
  ) async {
    final adapter = _adapters.firstWhere(
      (candidate) => candidate.supports(printer),
      orElse: () => const SystemPrintAdapter(),
    );
    return adapter.dispatch(printer, output);
  }
}
