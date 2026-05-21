import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'firebase_options.dart';
import 'licenses.dart';
import 'log.dart';
import 'model/binding.dart';
import 'notifications/receive.dart';
import 'widgets/app.dart';
import 'widgets/share.dart';

// This library defines the Dart entrypoint function for the
// headless Flutter engine used in our iOS "NotificationService" app extension.
// Importing it here causes it to be included in the build.
// ignore: unused_import
import 'notifications/ios_service.dart';

Future<void> main() async {
  await mainInit();
  runApp(const ZulipApp());
}

/// Everything [main] does short of [runApp].
///
/// This is useful for setup in Patrol-based integration tests.
Future<void> mainInit() async {
  assert(() {
    debugLogEnabled = true;
    return true;
  }());
  LicenseRegistry.addLicense(additionalLicenses);
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: defaultTargetPlatform == TargetPlatform.android
          ? kFirebaseOptionsAndroid
          : kFirebaseOptionsIos,
      );
    }
  } catch (e) {
    debugLog('Firebase initialization already completed: $e');
  }
  LiveZulipBinding.ensureInitialized();
  NotificationService.instance.start();
  ShareService.start();
}
