import 'package:flinkpos_v2/core/network/v2_api_debug_logger.dart';
import 'package:flinkpos_v2/core/services/sync/pos_v2_runtime_session_store.dart';
import 'package:flinkpos_v2/core/services/sync/wa_report_request_service.dart';
import 'package:flinkpos_v2/modules/settings/store/views/wa_report_request/wa_report_request_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sessionStore = PosV2RuntimeSessionStore.instance;

  setUp(() {
    sessionStore.setSession(
      const PosV2RuntimeSession(
        tenantId: 1,
        tenantKey: 'tenant-key',
        baseUrl: 'https://tenant.example',
        authToken: 'session-token',
        locationId: 'LOC01',
      ),
    );
  });

  tearDown(() => sessionStore.setSession(null));

  test('generates a key only through the V2 QR endpoint', () async {
    String? requestedEndpoint;
    Map<String, dynamic>? requestedBody;
    final service = WaReportRequestService(
      postRequest: (endpoint, body) async {
        requestedEndpoint = endpoint;
        requestedBody = body;
        return <String, dynamic>{'status': true, 'data': '9a8b7c6d'};
      },
    );

    final authKey = await service.generateAuthKey();

    expect(authKey, '9a8b7c6d');
    expect(requestedEndpoint, 'api/v2/pos-options');
    expect(requestedBody, isEmpty);
  });

  test('does not fabricate a key when the server does not issue one', () async {
    final service = WaReportRequestService(
      postRequest: (endpoint, body) async => <String, dynamic>{
        'status': true,
        'data': '',
      },
    );

    await expectLater(
      service.generateAuthKey(),
      throwsA(isA<WaReportRequestException>()),
    );
  });

  test('revokes the active key through the V2 QR endpoint', () async {
    String? requestedEndpoint;
    Map<String, dynamic>? requestedBody;
    final service = WaReportRequestService(
      postRequest: (endpoint, body) async {
        requestedEndpoint = endpoint;
        requestedBody = body;
        return <String, dynamic>{'status': true};
      },
    );

    expect(await service.revokeAuthKey(), isTrue);
    expect(requestedEndpoint, 'api/v2/pos-options');
    expect(requestedBody, <String, dynamic>{'auth_key': ''});
  });

  test('builds the expected WhatsApp payload', () {
    final payload = WaReportRequestService.instance.buildWaPayload(
      location: 'LOC01',
      authKey: '9a8b7c6d',
      requestType: 'OMZET 3 JAM',
    );

    expect(
      payload,
      'https://wa.me/6282322494484?text=id+mitra+%3A+LOC01+dengan+kode+%3A+9a8b7c6d+request+%3A+OMZET+3+JAM',
    );
  });

  test('redacts a generated report key from V2 API debug output', () {
    final messages = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => messages.add(message ?? '');
    addTearDown(() => debugPrint = originalDebugPrint);

    V2ApiDebugLogger.instance.log(
      V2ApiDebugEntry(
        requestId: 'request-id',
        timestamp: DateTime(2026),
        method: 'POST',
        url: 'https://tenant.example/api/v2/pos-options',
        headers: const <String, Object?>{},
        durationMs: 1,
        responseBody: const <String, dynamic>{
          'status': true,
          'data': '9a8b7c6d',
        },
      ),
    );

    expect(messages.join('\n'), isNot(contains('9a8b7c6d')));
    expect(messages.join('\n'), contains('<redacted>'));
  });

  testWidgets('issues only one key for each report-request screen session', (
    tester,
  ) async {
    var generatedKeyRequests = 0;
    WaReportRequestData? latestData;
    final service = WaReportRequestService(
      postRequest: (_, body) async {
        if (body.isEmpty) {
          generatedKeyRequests++;
          return <String, dynamic>{'status': true, 'data': '9a8b7c6d'};
        }
        return <String, dynamic>{'status': true};
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WaReportRequestContent(
          service: service,
          builder: (_, data) {
            latestData = data;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump();

    latestData!.onGenerateQr();
    await tester.pump();
    await tester.pump();

    expect(generatedKeyRequests, 1);
    expect(latestData!.qrPayload, contains('LOC01'));

    latestData!.onResetQr();
    await tester.pump();
    await tester.pump();
    latestData!.onGenerateQr();
    await tester.pump();
    await tester.pump();

    expect(generatedKeyRequests, 1);
  });
}
