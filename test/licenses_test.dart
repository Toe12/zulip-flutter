import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zulip/licenses.dart';

import 'fake_async.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('smoke: ensure all additional licenses load', () => awaitFakeAsync((async) async {
    await check(additionalLicenses().toList()).completes((it) {
      it.isNotEmpty();
      // Including the license of the Zulip app that this one is based on.
      it.has((entries) => entries.where((entry) =>
          entry.packages.any((package) => package.contains('Zulip'))).toList(),
            'Zulip entries').single
        .has((entry) => entry.paragraphs.map((p) => p.text).join('\n'), 'text')
          ..contains('Kandra Labs, Inc.')
          ..contains('Apache License');
    });
  }));
}
