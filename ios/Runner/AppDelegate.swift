import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var notificationTapEventListener: NotificationTapEventListener?

  // The implicit engine isn't created until the scene connects, which is after
  // this point, so hold the payload until there's a messenger to report it on.
  private var notificationDataFromLaunch: NotificationDataFromLaunch?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication
      .LaunchOptionsKey: Any]?
  ) -> Bool {
    // Retrieve the remote notification payload from launch options;
    // this will be null if the launch wasn't triggered by a notification.
    let notificationPayload =
      launchOptions?[.remoteNotification] as? [AnyHashable: Any]
    notificationDataFromLaunch =
      notificationPayload.map { NotificationDataFromLaunch(payload: $0) }

    UNUserNotificationCenter.current().delegate = self

    return super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
  }

  func didInitializeImplicitFlutterEngine(
    _ engineBridge: FlutterImplicitEngineBridge
  ) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()

    IosNativeHostApiSetup.setUp(
      binaryMessenger: messenger,
      api: IosNativeHostApiImpl()
    )

    NotificationHostApiSetup.setUp(
      binaryMessenger: messenger,
      api: NotificationHostApiImpl(notificationDataFromLaunch)
    )

    notificationTapEventListener = NotificationTapEventListener()
    NotificationTapEventsStreamHandler.register(
      with: messenger,
      streamHandler: notificationTapEventListener!
    )
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
      let userInfo = response.notification.request.content.userInfo
      notificationTapEventListener!.onNotificationTapEvent(payload: userInfo)
    }
    completionHandler()
  }
}

private class NotificationHostApiImpl: NotificationHostApi {
  private let maybeDataFromLaunch: NotificationDataFromLaunch?

  init(_ maybeDataFromLaunch: NotificationDataFromLaunch?) {
    self.maybeDataFromLaunch = maybeDataFromLaunch
  }

  func getNotificationDataFromLaunch() -> NotificationDataFromLaunch? {
    maybeDataFromLaunch
  }
}

// Adapted from Pigeon's Swift example for @EventChannelApi:
//   https://github.com/flutter/packages/blob/2dff6213a/packages/pigeon/example/app/ios/Runner/AppDelegate.swift#L49-L74
class NotificationTapEventListener: NotificationTapEventsStreamHandler {
  var eventSink: PigeonEventSink<NotificationTapEvent>?

  override func onListen(
    withArguments arguments: Any?,
    sink: PigeonEventSink<NotificationTapEvent>
  ) {
    eventSink = sink
  }

  func onNotificationTapEvent(payload: [AnyHashable: Any]) {
    eventSink?.success(IosNotificationTapEvent(payload: payload))
  }
}
