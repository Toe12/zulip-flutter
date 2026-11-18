// Renders App Store screenshots of the app's real screens, with made-up
// sample data, at the exact pixel sizes App Store Connect asks for.
//
// This is not part of the regular test suite (it lives outside `test/`).
// Run it with:
//
//   flutter test tool/app_store_screenshots/app_store_screenshots_test.dart
//
// and find the PNG files in `build/app_store_screenshots/`, or in the
// directory named by the SCREENSHOT_DIR environment variable.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zulip/api/model/model.dart';
import 'package:zulip/api/route/channels.dart';
import 'package:zulip/api/route/messages.dart';
import 'package:zulip/model/narrow.dart';
import 'package:zulip/model/typing_status.dart';
import 'package:zulip/widgets/home.dart';
import 'package:zulip/widgets/icons.dart';
import 'package:zulip/widgets/message_list.dart';

import '../../test/api/fake_api.dart';
import '../../test/example_data.dart' as eg;
import '../../test/model/binding.dart';
import '../../test/model/test_store.dart';
import '../../test/widgets/test_app.dart';

/// A device size that App Store Connect accepts screenshots for.
class _Device {
  const _Device(this.name, {
    required this.pixelWidth,
    required this.pixelHeight,
    required this.pixelRatio,
    required this.topInset,
    required this.bottomInset,
  });

  final String name;
  final int pixelWidth;
  final int pixelHeight;
  final double pixelRatio;

  /// Status bar and notch, in logical pixels.
  final double topInset;

  /// Home indicator, in logical pixels.
  final double bottomInset;
}

const _devices = [
  // iPhone 6.9-inch display.
  _Device('iphone-6.9', pixelWidth: 1320, pixelHeight: 2868, pixelRatio: 3,
    topInset: 62, bottomInset: 34),
  // iPad 13-inch display.
  _Device('ipad-13', pixelWidth: 2064, pixelHeight: 2752, pixelRatio: 2,
    topInset: 24, bottomInset: 20),
];

final _now = DateTime(2026, 11, 18, 9, 41);
int _ago(Duration d) => _now.subtract(d).millisecondsSinceEpoch ~/ 1000;

String _p(String text) => '<p>$text</p>';

/// Flutter's test mode substitutes a blocky test font for every font.
/// Load the app's real fonts, so the screenshots show real text and icons.
Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      final bytes = File(path).readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
    }
    await loader.load();
  }

  await load('Source Sans 3', [
    'assets/Source_Sans_3/SourceSans3VF-Upright.otf',
    'assets/Source_Sans_3/SourceSans3VF-Italic.otf',
  ]);
  await load('Source Code Pro', [
    'assets/Source_Code_Pro/SourceCodeVF-Upright.otf',
    'assets/Source_Code_Pro/SourceCodeVF-Italic.otf',
  ]);
  await load('Zulip Icons', ['assets/icons/ZulipIcons.ttf']);
  await load('Noto Color Emoji', ['assets/Noto_Color_Emoji/Noto-COLRv1.ttf']);

  // The Flutter SDK keeps the Material icon font next to the test shell.
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final materialIcons = File(
    '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf');
  if (materialIcons.existsSync()) {
    await load('MaterialIcons', [materialIcons.path]);
  }
}

/// A stand-in for the system status bar, which the app doesn't draw itself.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontFamily: 'Source Sans 3', fontSize: 17,
      fontWeight: FontWeight.w600, color: Color(0xff000000),
      decoration: TextDecoration.none);
    const icon = Color(0xff000000);
    return Positioned(top: 0, left: 0, right: 0, height: height,
      child: IgnorePointer(child: Padding(
        padding: EdgeInsets.fromLTRB(36, height > 40 ? 14 : 0, 32, 0),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('9:41', style: style),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.signal_cellular_alt, size: 20, color: icon),
              SizedBox(width: 6),
              Icon(Icons.wifi, size: 20, color: icon),
              SizedBox(width: 6),
              Icon(Icons.battery_full, size: 22, color: icon),
            ]),
          ]))));
  }
}

void main() {
  TestZulipBinding.ensureInitialized();
  WidgetsApp.debugAllowBannerOverride = false;
  setUpAll(_loadFonts);
  MessageListPage.debugEnableMarkReadOnScroll = false;
  TypingNotifier.debugEnable = false;

  final self = eg.user(userId: eg.selfUser.userId,
    fullName: 'Alex Morgan', role: UserRole.member);
  final maria = eg.user(userId: 201, fullName: 'Maria Santos',
    role: UserRole.administrator);
  final james = eg.user(userId: 202, fullName: 'James Carter');
  final priya = eg.user(userId: 203, fullName: 'Priya Patel');
  final luis = eg.user(userId: 204, fullName: 'Luis Ortega');
  final dana = eg.user(userId: 205, fullName: 'Dana Whitfield');
  final omar = eg.user(userId: 206, fullName: 'Omar Haddad');
  final grace = eg.user(userId: 207, fullName: 'Grace Nakamura');
  final people = [self, maria, james, priya, luis, dana, omar, grace];

  final announcements = eg.stream(streamId: 5, name: 'announcements');
  final dispatch = eg.stream(streamId: 2, name: 'dispatch');
  final warehouse = eg.stream(streamId: 3, name: 'warehouse');
  final drivers = eg.stream(streamId: 4, name: 'drivers');
  final safety = eg.stream(streamId: 6, name: 'safety');
  final maintenance = eg.stream(streamId: 7, name: 'maintenance');
  final customerService = eg.stream(streamId: 8, name: 'customer-service');
  final billing = eg.stream(streamId: 9, name: 'billing');
  final general = eg.stream(streamId: 1, name: 'general');
  final channels = [announcements, dispatch, warehouse, drivers, safety,
    maintenance, customerService, billing, general];
  final subscriptions = [
    eg.subscription(announcements, color: 0xfff4511e, pinToTop: true),
    eg.subscription(safety, color: 0xffd81b60, pinToTop: true),
    eg.subscription(dispatch, color: 0xff3367d6),
    eg.subscription(warehouse, color: 0xff0b8043),
    eg.subscription(drivers, color: 0xff8e24aa),
    eg.subscription(maintenance, color: 0xffef6c00),
    eg.subscription(customerService, color: 0xff00897b),
    eg.subscription(billing, color: 0xff5c6bc0),
    eg.subscription(general, color: 0xff616161),
  ];

  var nextId = 1000;

  /// A conversation: (sender, text, minutes before [_now]).
  List<StreamMessage> channelThread(ZulipStream stream, String topic,
      List<(User, String, int)> lines, {bool read = true}) {
    return [for (final (sender, text, minutesAgo) in lines)
      eg.streamMessage(id: nextId++, stream: stream, topic: topic,
        sender: sender, timestamp: _ago(Duration(minutes: minutesAgo)),
        flags: read ? [MessageFlag.read] : [], content: _p(text))];
  }

  List<DmMessage> dmThread(User other, List<(User, String, int)> lines,
      {bool read = true}) {
    return [for (final (sender, text, minutesAgo) in lines)
      eg.dmMessage(id: nextId++,
        from: sender, to: [sender.userId == self.userId ? other : self],
        timestamp: _ago(Duration(minutes: minutesAgo)),
        flags: read ? [MessageFlag.read] : [], content: _p(text))];
  }

  const routeTopic = 'Route 14: Omaha to Des Moines';
  final routeMessages = channelThread(dispatch, routeTopic, [
    (maria, 'Good morning! Route 14 loads at Dock 6 at 7:30. Please confirm your trucks are ready.', 220),
    (james, 'Truck 22 is fueled and inspected. Ready to go.', 214),
    (priya, 'Truck 31 too. Trailer seal numbers are in the load sheet.', 205),
    (maria, 'Thanks both. Weather looks clear on I-80, so no delays expected.', 190),
    (luis, 'Arrived at Dock 6. Starting to load now.', 160),
    (dana, 'Loading crew is on it. 24 pallets total, 2 are temperature controlled.', 154),
    (priya, 'Reminder: all drivers need the new delivery checklist.', 148),
    (maria, 'Yes, it is posted in #announcements. Thanks, Priya.', 146),
    (luis, 'Got it. The reefer unit is set to 36°F.', 130),
    (maria, 'Perfect. Please send a photo of the seal once the doors are closed.', 124),
    (luis, 'Pickup complete. 24 pallets loaded, departing now.', 95),
    (maria, 'Great work, Luis. Please message when you reach the Des Moines yard.', 90),
    (james, 'Receiving at Des Moines confirmed an 11:15 dock slot for us.', 60),
    (dana, 'The receiving contact is Marcus, extension 204.', 55),
    (luis, 'Thanks, saved. Crossing the Missouri River now, traffic is light.', 50),
    (priya, 'Billing needs the signed bill of lading by end of day.', 30),
    (james, 'Will upload it right after delivery.', 25),
    (maria, 'Thanks everyone. Nice teamwork on this one.', 12),
  ]);

  final dmWithMaria = dmThread(maria, [
    (maria, 'Hi Alex, can you cover the Friday dock schedule?', 300),
    (self, 'Sure, I can take the morning shift. Do you need the afternoon too?', 295),
    (maria, 'Morning is perfect. I will handle the afternoon.', 290),
    (self, 'Great. I will update the schedule in the dispatch channel.', 285),
    (maria, 'Thank you! Also, the new driver checklist is posted in #announcements.', 240),
    (self, 'Saw it. I will walk the Friday crew through it at the start of shift.', 235),
    (maria, 'Perfect. Let me know if anyone has questions.', 230),
    (self, 'Will do. Is dock 4 still closed for repairs?', 120),
    (maria, 'It reopens Thursday afternoon, so Friday is fine.', 110),
    (self, 'Good to know. I will plan for all six docks.', 105),
    (maria, 'Great. Thanks again, Alex!', 20),
  ]);

  // Unread messages, which make the Inbox and Channels screens lively.
  final unreadStreamMessages = [
    ...channelThread(announcements, 'Holiday schedule', [
      (maria, 'The holiday schedule for December is now posted.', 240),
    ], read: false),
    ...channelThread(announcements, 'New driver checklist', [
      (maria, 'Every driver needs the new checklist before the next trip.', 200),
      (grace, 'It is in the shared folder, with a one-page summary.', 190),
    ], read: false),
    ...channelThread(safety, 'Winter safety reminders', [
      (omar, 'Please check tire pressure every morning during cold weather.', 90),
      (grace, 'Chains are available at the front desk if you need them.', 80),
      (maria, 'Thanks both. Safety first!', 70),
    ], read: false),
    ...channelThread(dispatch, routeTopic, [
      (james, 'Receiving at Des Moines confirmed an 11:15 dock slot for us.', 60),
      (maria, 'Thanks everyone. Nice teamwork on this one.', 12),
    ], read: false),
    ...channelThread(dispatch, 'Dock schedule: Friday', [
      (maria, 'Morning shift is covered. Afternoon still open.', 120),
    ], read: false),
    ...channelThread(warehouse, 'Cycle count: aisle 7', [
      (dana, 'Count finished. Two location mismatches to review.', 30),
      (dana, 'Photos of the labels are in the shared folder.', 28),
      (priya, 'Thanks, I will fix the labels after lunch.', 20),
    ], read: false),
    ...channelThread(warehouse, 'Forklift inspection', [
      (luis, 'Forklift 3 passed. Forklift 5 needs a new tire.', 60),
    ], read: false),
    ...channelThread(drivers, 'Weather delays on I-80', [
      (james, 'Snow near Lincoln. Allow an extra hour tomorrow.', 80),
      (priya, 'Noted. I will let the customers know.', 60),
    ], read: false),
    ...channelThread(maintenance, 'Truck 22 brake service', [
      (omar, 'Brake service is scheduled for Thursday at 8 AM.', 150),
      (luis, 'I can bring the truck in Wednesday evening.', 140),
    ], read: false),
    ...channelThread(customerService, 'Delivery window question', [
      (grace, 'A customer asked about Friday morning delivery.', 45),
    ], read: false),
    ...channelThread(billing, 'November invoices', [
      (priya, 'Invoices go out Friday. Please send missing documents today.', 100),
      (dana, 'Warehouse documents are all uploaded.', 90),
    ], read: false),
  ];
  final unreadDms = [
    ...dmThread(maria, [
      (maria, 'Great. Thanks again, Alex!', 20),
    ], read: false),
    ...dmThread(james, [
      (james, 'Do you have the Route 14 load sheet?', 8),
    ], read: false),
    ...dmThread(grace, [
      (grace, 'Can we move our check-in to 3 PM?', 35),
      (grace, 'No rush, whenever you see this.', 34),
    ], read: false),
  ];

  Future<void> prepare(WidgetTester tester, _Device device, {
    required Widget child,
    List<Message> read = const [],
    List<Message> unread = const [],
    List<List<dynamic>> apiResponses = const [],
    GetMessagesResult? fetchResult,
  }) async {
    addTearDown(testBinding.reset);
    final view = tester.view;
    view.physicalSize = Size(device.pixelWidth.toDouble(), device.pixelHeight.toDouble());
    view.devicePixelRatio = device.pixelRatio;
    final inset = FakeViewPadding(
      top: device.topInset * device.pixelRatio,
      bottom: device.bottomInset * device.pixelRatio);
    view.padding = inset;
    view.viewPadding = inset;
    addTearDown(view.reset);

    await testBinding.globalStore.add(eg.selfAccount,
      eg.initialSnapshot(streams: channels,
        subscriptions: subscriptions));
    final store = await testBinding.globalStore.perAccount(eg.selfAccount.id);
    await store.addUsers(people);
    for (final message in [...read, ...unread]) {
      await store.addMessage(message);
    }
    final connection = store.connection as FakeApiConnection;
    if (fetchResult != null) {
      connection.prepare(json: fetchResult.toJson());
      connection.prepare(json: GetChannelTopicsResult(topics: []).toJson());
    }

    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('screenshot'),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(children: [
          TestZulipApp(accountId: eg.selfAccount.id, child: child),
          _StatusBar(height: device.topInset),
        ]))));
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, _Device device, String name) async {
    await tester.pump(const Duration(seconds: 1));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('screenshot')));
    final dir = Directory(Platform.environment['SCREENSHOT_DIR']
      ?? 'build/app_store_screenshots')..createSync(recursive: true);
    await tester.runAsync(() async {
      final ui.Image image = await boundary.toImage(pixelRatio: device.pixelRatio);
      expect((image.width, image.height), (device.pixelWidth, device.pixelHeight));
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${dir.path}/${device.name}-$name.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  for (final device in _devices) {
    testWidgets('${device.name}: inbox', (tester) async {
      await prepare(tester, device, child: const HomePage(),
        unread: [...unreadStreamMessages, ...unreadDms]);
      await capture(tester, device, '1-inbox');
    });

    testWidgets('${device.name}: channels', (tester) async {
      await prepare(tester, device, child: const HomePage(),
        unread: [...unreadStreamMessages, ...unreadDms]);
      await tester.tap(find.byIcon(ZulipIcons.hash_italic));
      await tester.pumpAndSettle();
      await capture(tester, device, '2-channels');
    });

    testWidgets('${device.name}: conversation', (tester) async {
      await prepare(tester, device,
        child: MessageListPage(initNarrow: TopicNarrow(
          dispatch.streamId, TopicName(routeTopic))),
        read: routeMessages,
        fetchResult: eg.newestGetMessagesResult(
          foundOldest: true, messages: routeMessages));
      await capture(tester, device, '3-conversation');
    });

    testWidgets('${device.name}: direct message', (tester) async {
      await prepare(tester, device,
        child: MessageListPage(initNarrow: DmNarrow.withUser(
          maria.userId, selfUserId: self.userId)),
        read: dmWithMaria,
        fetchResult: eg.newestGetMessagesResult(
          foundOldest: true, messages: dmWithMaria));
      await capture(tester, device, '4-direct-message');
    });
  }
}
