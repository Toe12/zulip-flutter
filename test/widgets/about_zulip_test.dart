import 'package:checks/checks.dart';
import 'package:flutter_checks/flutter_checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zulip/widgets/about_zulip.dart';

import '../model/binding.dart';
import 'test_app.dart';

void main() {
  TestZulipBinding.ensureInitialized();

  Future<void> prepare(WidgetTester tester) async {
    addTearDown(testBinding.reset);
    await tester.pumpWidget(TestZulipApp(child: AboutZulipPage()));
    await tester.pump();
  }

  testWidgets('credits Zulip, and tapping the credit opens its website', (tester) async {
    await prepare(tester);
    check(find.text('Based on Zulip')).findsOne();

    await tester.tap(find.text('Based on Zulip'));
    await tester.pump();
    check(testBinding.takeLaunchUrlCalls())
      .single.has((call) => call.url, 'url').equals(Uri.parse('https://zulip.com'));
  });

  testWidgets('links to the open-source licenses', (tester) async {
    await prepare(tester);
    check(find.text('Open-source licenses')).findsOne();
  });
}
