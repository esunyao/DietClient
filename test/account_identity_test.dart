import 'package:diet_client/core/network/api_client.dart';
import 'package:diet_client/core/presentation/account_identity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_api_test.dart' show FakeAdapter, client, envelope;

void main() {
  final cases = <(String, Map<String, dynamic>, String)>[
    (
      'display name takes precedence',
      {'displayName': '小云', 'username': 'esuny'},
      '小云',
    ),
    (
      'display name is trimmed',
      {'displayName': '  小云  ', 'username': 'esuny'},
      '小云',
    ),
    ('missing display name uses username', {'username': 'esuny'}, 'esuny'),
    (
      'null display name uses username',
      {'displayName': null, 'username': 'esuny'},
      'esuny',
    ),
    (
      'empty display name uses username',
      {'displayName': '', 'username': 'esuny'},
      'esuny',
    ),
    (
      'whitespace display name uses trimmed username',
      {'displayName': ' \t\n ', 'username': ' esuny '},
      'esuny',
    ),
    ('missing names use placeholder', {}, '姓名未提供'),
    (
      'null names use placeholder',
      {'displayName': null, 'username': null},
      '姓名未提供',
    ),
    (
      'empty names use placeholder',
      {'displayName': '', 'username': ''},
      '姓名未提供',
    ),
    (
      'whitespace names use placeholder',
      {'displayName': ' ', 'username': '\t '},
      '姓名未提供',
    ),
  ];

  for (final (description, user, expected) in cases) {
    test(description, () async {
      final adapter = FakeAdapter((_) => envelope(user));
      final api = client(adapter);
      addTearDown(api.close);
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);

      final account = await container.read(accountIdentityProvider.future);

      expect(account.name, expected);
      expect(adapter.requests.single.uri.path, '/v1/users/self');
    });
  }
}
