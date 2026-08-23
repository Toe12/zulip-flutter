import 'package:firebase_core/firebase_core.dart';

/// Configuration used for receiving notifications on Android.
///
/// This set of options is used for receiving notifications
/// through the self-hosted notification bouncer service.
/// We deliver Android notifications through Firebase Cloud Messaging (FCM).
/// The values are derived from the `android/app/google-services.json` file
/// for the `base-comms` Firebase project.
const kFirebaseOptionsAndroid = FirebaseOptions(
  appId: '1:${_ZulipFirebaseOptions.projectNumber}:android:7ebdf2ebc5793efc8d12cb',
  messagingSenderId: _ZulipFirebaseOptions.projectNumber,
  projectId: _ZulipFirebaseOptions.projectId,
  apiKey: 'AIzaSyAsnIqc6adQ4NPiGJ3EAMIA1xHMDPZ_EWA',
);

/// Configuration used for finding the notification token on iOS.
///
/// On iOS, we don't use Firebase to actually deliver notifications;
/// rather the notification bouncer service communicates with
/// the Apple Push Notification service (APNs) directly.
///
/// But we do use the Firebase library as a convenient binding to the
/// platform API for the setup steps of requesting the user's permission
/// to show notifications, and getting the token that the service uses
/// to represent that permission.
///
/// The values are derived from the `ios/GoogleService-Info.plist` file
/// for the `base-comms` Firebase project.
const kFirebaseOptionsIos = FirebaseOptions(
  appId: '1:${_ZulipFirebaseOptions.projectNumber}:ios:525a7c50d43ece5f8d12cb',
  messagingSenderId: _ZulipFirebaseOptions.projectNumber,
  projectId: _ZulipFirebaseOptions.projectId,
  apiKey: 'AIzaSyDWiAeCw7ZuNvxhqMDQTS885c0YqIYMgQc',
);

abstract class _ZulipFirebaseOptions {
  static const projectNumber = '9268334098';

  // This name applies across Android and iOS.
  static const projectId = 'base-comms';

  // The per-platform Google Cloud "API key" values are set directly in
  // [kFirebaseOptionsAndroid] and [kFirebaseOptionsIos] above, since the
  // Android and iOS apps in the `base-comms` project use different keys.
  //
  // Despite the name, a Google Cloud "API key" is a very different kind of
  // thing from a Zulip "API key".  In particular, it's designed to be
  // included in published builds of client applications, and is therefore
  // fundamentally public.  See docs:
  //   https://cloud.google.com/docs/authentication/api-keys
}
