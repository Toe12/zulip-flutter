import 'package:checks/checks.dart';
import 'package:http/http.dart' as http;
import 'package:test/scaffolding.dart';
import 'package:zulip/api/route/message_translation.dart';

import '../../model/binding.dart';
import '../../stdlib_checks.dart';
import '../fake_api.dart';

void main() {
  TestZulipBinding.ensureInitialized();

  test('smoke', () {
    return FakeApiConnection.with_((connection) async {
      connection.prepare(json: TranslateMessageResult(source: 'en', target: 'es',
        sameLanguage: false, content: '<p>Hola</p>', strings: null).toJson());
      final result = await translateMessage(connection, messageId: 42, target: 'es');
      check(connection.takeRequests()).single.isA<http.Request>()
        ..method.equals('POST')
        ..url.path.equals('/api/v1/messages/42/translate')
        ..bodyFields.deepEquals({'target': 'es'});
      check(result)
        ..has((r) => r.source, 'source').equals('en')
        ..has((r) => r.content, 'content').equals('<p>Hola</p>');
    });
  });
}
