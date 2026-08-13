import 'dart:convert';

import 'package:flinkpos_v2/core/network/v2_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'GET normalizes URL, serializes query, and includes the POS token',
    () async {
      late http.Request capturedRequest;
      final client = V2ApiClient(
        baseUrl: 'https://tenant.example/',
        authToken: ' session-token ',
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode(<String, dynamic>{'status': true}),
            200,
          );
        }),
      );

      final response = await client.getEnvelope(
        '/api/v2/pos-options',
        query: <String, dynamic>{'name': 'pos_tax', 'active': true},
      );

      expect(response['status'], isTrue);
      expect(capturedRequest.method, 'GET');
      expect(capturedRequest.url.toString(), contains('/api/v2/pos-options?'));
      expect(capturedRequest.url.queryParameters, <String, String>{
        'name': 'pos_tax',
        'active': 'true',
      });
      expect(capturedRequest.headers['authtoken'], 'session-token');
      expect(capturedRequest.headers, isNot(contains('content-type')));
    },
  );

  test('POST serializes JSON body and uses JSON headers', () async {
    late http.Request capturedRequest;
    final client = V2ApiClient(
      baseUrl: 'https://tenant.example',
      authToken: 'session-token',
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode(<String, dynamic>{'status': true, 'data': <String>[]}),
          200,
        );
      }),
    );

    await client.postEnvelope(
      'api/v2/pos-options',
      body: <String, dynamic>{'pos_tax': 11},
    );

    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.headers['content-type'], 'application/json');
    expect(capturedRequest.headers['authtoken'], 'session-token');
    expect(jsonDecode(capturedRequest.body), <String, dynamic>{'pos_tax': 11});
  });

  test('DELETE sends the specified JSON body', () async {
    late http.Request capturedRequest;
    final client = V2ApiClient(
      baseUrl: 'https://tenant.example',
      authToken: '',
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode(<String, dynamic>{'status': true}),
          200,
        );
      }),
    );

    await client.deleteEnvelope(
      'api/v2/backoffice/pos-registers/7',
      body: <String, dynamic>{'acting_staff_id': '42'},
    );

    expect(capturedRequest.method, 'DELETE');
    expect(capturedRequest.headers.containsKey('authtoken'), isFalse);
    expect(jsonDecode(capturedRequest.body), <String, dynamic>{
      'acting_staff_id': '42',
    });
  });

  test('throws the backend message for unsuccessful envelopes', () async {
    final client = V2ApiClient(
      baseUrl: 'https://tenant.example',
      authToken: 'session-token',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode(<String, dynamic>{
            'status': false,
            'message': 'Shift masih aktif',
          }),
          409,
        ),
      ),
    );

    await expectLater(
      client.postEnvelope('api/v2/pos-shift-sessions/open'),
      throwsA(
        predicate((error) => error.toString().contains('Shift masih aktif')),
      ),
    );
  });

  test('keeps a no-data envelope available to callers', () async {
    final client = V2ApiClient(
      baseUrl: 'https://tenant.example',
      authToken: 'session-token',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode(<String, dynamic>{
            'status': false,
            'message': 'No data found',
          }),
          200,
        ),
      ),
    );

    final response = await client.getEnvelope('api/v2/pos-items');

    expect(response['status'], isFalse);
    expect(response['message'], 'No data found');
  });
}
