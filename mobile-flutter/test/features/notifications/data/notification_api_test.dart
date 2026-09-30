import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_flutter/core/api/api_client.dart';
import 'package:mobile_flutter/features/notifications/data/notification_api.dart';

import '../../../support/json_fixtures.dart';

const _base = 'http://api.test/api/v1';

void main() {
  late List<http.Request> requests;
  late HttpNotificationRepository repository;

  setUp(() {
    requests = [];
    repository = HttpNotificationRepository(
      ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return http.Response.bytes(
              utf8.encode(jsonEncode([notificationJson(id: 21)])),
              200,
            );
          }
          return http.Response('', 204);
        }),
        baseUrl: _base,
      ),
    );
  });

  test('list asks for all or only the unread', () async {
    final all = await repository.list();
    await repository.list(unreadOnly: true);

    expect(requests[0].url.toString(), '$_base/notifications');
    expect(requests[1].url.toString(), '$_base/notifications?unreadOnly=true');
    expect(all.single.id, 21);
  });

  test('markRead and markAllRead', () async {
    await repository.markRead(21);
    await repository.markAllRead();

    expect(requests.map((r) => '${r.method} ${r.url}'), [
      'POST $_base/notifications/21/read',
      'POST $_base/notifications/read-all',
    ]);
  });
}
