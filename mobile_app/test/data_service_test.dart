import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:employee_tasks_mobile/data_service.dart';

void main() {
  const daily = {
    'date': '2026-11-26',
    'updated_at': '2026-11-26T11:21:49+06:30',
    'tasks': [
      {
        'id': '20261126-01',
        'task': 'Review',
        'assigned_to': {'username': 'di_qing_bai'},
        'description': 'Check the report.',
        'status': 'active',
      }
    ]
  };

  test('builds the server URL', () {
    final service = DataService(baseUrl: 'https://example.com/', token: 'abc');
    expect(service.uriFor('/api/mobile/dates').toString(),
        'https://example.com/api/mobile/dates');
  });

  test('sends the token and parses the dates list', () async {
    String? seenToken;
    final client = MockClient((request) async {
      seenToken = request.headers['X-Mobile-Token'];
      return Response(jsonEncode({'dates': ['2026-11-26']}), 200);
    });
    final service = DataService(
        baseUrl: 'https://example.com', token: 'secret', client: client);
    expect(await service.fetchDates(), ['2026-11-26']);
    expect(seenToken, 'secret');
  });

  test('parses a daily log from the server', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/api/mobile/data/2026-11-26')) {
        return Response(jsonEncode(daily), 200);
      }
      return Response('not found', 404);
    });
    final service = DataService(
        baseUrl: 'https://example.com', token: 'secret', client: client);
    final log = await service.fetchDay('2026-11-26');
    expect(log.date, '2026-11-26');
    expect(log.tasks.single.title, 'Review');
  });

  test('reports a rejected token', () async {
    final client = MockClient((_) async => Response('unauthorized', 401));
    final service = DataService(
        baseUrl: 'https://example.com', token: 'bad', client: client);
    expect(service.fetchDates(), throwsA(isA<DataServiceException>()));
  });

  test('requires server URL and token', () async {
    final service = DataService(baseUrl: '', token: '');
    expect(service.fetchDates(), throwsA(isA<DataServiceException>()));
  });
}
