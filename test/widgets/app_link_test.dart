import 'package:checks/checks.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zulip/api/model/model.dart';
import 'package:zulip/api/route/channels.dart';
import 'package:zulip/api/route/messages.dart';
import 'package:zulip/model/database.dart';
import 'package:zulip/model/narrow.dart';
import 'package:zulip/model/store.dart';
import 'package:zulip/widgets/app.dart';
import 'package:zulip/widgets/app_link.dart';
import 'package:zulip/widgets/home.dart';
import 'package:zulip/widgets/message_list.dart';
import 'package:zulip/widgets/page.dart';

import '../api/fake_api.dart';
import '../example_data.dart' as eg;
import '../model/binding.dart';
import '../test_navigation.dart';
import 'checks.dart';

void main() {
  TestZulipBinding.ensureInitialized();
  MessageListPage.debugEnableMarkReadOnScroll = false;

  final channel = eg.stream(streamId: 7, name: 'general');
  final ownRealm = eg.realmUrl; // https://chat.example/
  final otherRealm = Uri.parse('https://other.example/');
  final otherRealmAccount = eg.account(
    id: 1010, realmUrl: otherRealm, user: eg.thirdUser);

  late List<Route<dynamic>> pushedRoutes;

  Future<void> prepare(WidgetTester tester, {
    bool withOtherRealmAccount = false,
    String? launchedByLink,
    Message? messageToFind,
    bool messageFetchFails = false,
  }) async {
    addTearDown(testBinding.reset);
    addTearDown(AppLink.debugReset);

    await testBinding.globalStore.add(eg.selfAccount,
      eg.initialSnapshot(streams: [channel]));
    if (withOtherRealmAccount) {
      // The account added last is the one the app starts in.
      await testBinding.globalStore.add(otherRealmAccount,
        eg.initialSnapshot(streams: [channel], realmUsers: [eg.thirdUser]));
    }

    // Each narrow page we open fetches its messages and, for the compose
    // box, the channel's topics.
    for (final account in testBinding.globalStore.accounts) {
      final store = await testBinding.globalStore.perAccount(account.id);
      final connection = store.connection as FakeApiConnection;
      if (messageToFind != null && account.id == eg.selfAccount.id) {
        connection.prepare(json: GetMessageResult(message: messageToFind).toJson());
      }
      if (messageFetchFails && account.id == eg.selfAccount.id) {
        connection.prepare(apiException: eg.apiBadRequest());
      }
      for (var i = 0; i < 2; i++) {
        connection.prepare(json: eg.newestGetMessagesResult(
          foundOldest: true, messages: []).toJson());
        connection.prepare(json: GetChannelTopicsResult(topics: []).toJson());
      }
    }

    if (launchedByLink != null) {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = launchedByLink;
      addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
    }

    pushedRoutes = [];
    final testNavObserver = TestNavigatorObserver();
    testNavObserver.onPushed = (route, prevRoute) => pushedRoutes.add(route);
    // Switching accounts replaces the home page.
    testNavObserver.onReplaced = (route, prevRoute) {
      if (route != null) pushedRoutes.add(route);
    };
    await tester.pumpWidget(ZulipApp(navigatorObservers: [testNavObserver]));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  /// Deliver [link] to the app, as the platform does when the system
  /// opens a web link in the app.
  Future<void> deliver(WidgetTester tester, String link) async {
    final ByteData message = const JSONMethodCodec().encodeMethodCall(
      MethodCall('pushRouteInformation', {'location': link}));
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation', message, null);
    // Let the account's data load, and the page be pushed.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  Condition<Object?> isHomePage(Account account) => (it) => it
    .isA<MaterialAccountWidgetRoute>()
    ..accountId.equals(account.id)
    ..page.isA<HomePage>();

  Condition<Object?> isNarrowPage(Account account, Narrow narrow, {int? anchor}) =>
    (it) => it
      .isA<MaterialAccountWidgetRoute>()
      ..accountId.equals(account.id)
      ..page.isA<MessageListPage>().which((page) => page
        ..initNarrow.equals(narrow)
        ..initAnchorMessageId.equals(anchor));

  group('web link opened in the app', () {
    testWidgets('a narrow link on the account\'s realm opens that narrow', (tester) async {
      await prepare(tester);
      pushedRoutes.clear();

      await deliver(tester, '$ownRealm#narrow/channel/7-general');

      check(pushedRoutes).deepEquals(<Condition<Object?>>[
        isNarrowPage(eg.selfAccount, ChannelNarrow(channel.streamId)),
      ]);
    });

    testWidgets('a link to a particular message opens at that message', (tester) async {
      await prepare(tester);
      pushedRoutes.clear();

      await deliver(tester, '$ownRealm#narrow/channel/7-general/near/123');

      check(pushedRoutes).deepEquals(<Condition<Object?>>[
        isNarrowPage(eg.selfAccount, ChannelNarrow(channel.streamId), anchor: 123),
      ]);
    });

    testWidgets('a link on a realm of another account '
        'switches to that account first', (tester) async {
      await prepare(tester, withOtherRealmAccount: true);
      check(ZulipApp.navigationStack!.currentAccountId)
        .equals(otherRealmAccount.id);
      pushedRoutes.clear();

      await deliver(tester, '$ownRealm#narrow/channel/7-general');

      check(pushedRoutes).deepEquals(<Condition<Object?>>[
        isHomePage(eg.selfAccount),
        isNarrowPage(eg.selfAccount, ChannelNarrow(channel.streamId)),
      ]);
    });

    testWidgets('a message link opens the message\'s conversation, at the message', (tester) async {
      final message = eg.streamMessage(id: 488, stream: channel, topic: 'hello');
      await prepare(tester, messageToFind: message);
      pushedRoutes.clear();

      await deliver(tester, '$ownRealm#narrow/id/488');

      check(pushedRoutes).deepEquals(<Condition<Object?>>[
        isNarrowPage(eg.selfAccount, TopicNarrow.ofMessage(message), anchor: 488),
      ]);
    });

    testWidgets('a message link on the login page path is also opened', (tester) async {
      final message = eg.streamMessage(id: 488, stream: channel, topic: 'hello');
      await prepare(tester, messageToFind: message);
      pushedRoutes.clear();

      await deliver(tester, '${ownRealm}login/#narrow/id/488');

      check(pushedRoutes).deepEquals(<Condition<Object?>>[
        isNarrowPage(eg.selfAccount, TopicNarrow.ofMessage(message), anchor: 488),
      ]);
    });

    testWidgets('a message link to a message we cannot get is ignored', (tester) async {
      await prepare(tester, messageFetchFails: true);
      pushedRoutes.clear();

      await deliver(tester, '$ownRealm#narrow/id/488');

      check(pushedRoutes).isEmpty();
    });

    testWidgets('a link on a realm we have no account for is ignored', (tester) async {
      await prepare(tester);
      pushedRoutes.clear();

      await deliver(tester, 'https://stranger.example/#narrow/channel/7-general');

      check(pushedRoutes).isEmpty();
    });

    testWidgets('a link that is not to a narrow is ignored', (tester) async {
      await prepare(tester);
      pushedRoutes.clear();

      await deliver(tester, '${ownRealm}login/');
      await deliver(tester, '${ownRealm}help/getting-started');
      await deliver(tester, '$ownRealm#settings/profile');

      check(pushedRoutes).isEmpty();
    });

    testWidgets('a narrow the app does not understand '
        'leaves the account\'s home page', (tester) async {
      await prepare(tester);
      pushedRoutes.clear();

      await deliver(tester, '$ownRealm#narrow/nonsense/xyz');

      check(pushedRoutes).isEmpty();
    });

    testWidgets('the same link arriving twice at once opens one page', (tester) async {
      await prepare(tester);
      pushedRoutes.clear();

      await deliver(tester, '$ownRealm#narrow/channel/7-general');
      await deliver(tester, '$ownRealm#narrow/channel/7-general');

      check(pushedRoutes).length.equals(1);
    });

    testWidgets('the same link again, after a while, opens again', (tester) async {
      await prepare(tester);
      pushedRoutes.clear();

      final start = DateTime.utc(2026, 1, 1);
      await withClock(Clock.fixed(start), () =>
        deliver(tester, '$ownRealm#narrow/channel/7-general'));
      await withClock(Clock.fixed(start.add(const Duration(seconds: 10))), () =>
        deliver(tester, '$ownRealm#narrow/channel/7-general'));

      check(pushedRoutes).length.equals(2);
    });

    testWidgets('a link that launches the app starts in its account, '
        'then opens the narrow', (tester) async {
      await prepare(tester, launchedByLink: '$ownRealm#narrow/channel/7-general');

      check(pushedRoutes).deepEquals(<Condition<Object?>>[
        isHomePage(eg.selfAccount),
        isNarrowPage(eg.selfAccount, ChannelNarrow(channel.streamId)),
      ]);
    });

    testWidgets('a link that launches the app, on a realm we have no account for, '
        'starts as usual', (tester) async {
      await prepare(tester,
        launchedByLink: 'https://stranger.example/#narrow/channel/7-general');

      check(pushedRoutes).deepEquals(<Condition<Object?>>[
        isHomePage(eg.selfAccount),
      ]);
    });
  });
}
