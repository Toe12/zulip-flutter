import Flutter
import UserNotifications
import os

/// See docs:
///   https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension
///   https://developer.apple.com/documentation/usernotifications/modifying-content-in-newly-delivered-notifications
class NotificationService: UNNotificationServiceExtension {
  let logger = Logger()

  var contentHandler: ((UNNotificationContent) -> Void)?
  var bestAttemptContent: UNMutableNotificationContent?
  var headlessEngine: FlutterEngine?

  /// See docs: https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension/didreceive(_:withcontenthandler:)
  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    bestAttemptContent =
      (request.content.mutableCopy() as? UNMutableNotificationContent)
    guard let bestAttemptContent = bestAttemptContent else {
      contentHandler(request.content)  // TODO(log)
      return
    }

    // iOS calls this method on a background thread, but FlutterEngine
    // must be created and run on the main thread; the extension's main
    // thread already runs an event loop, which then drives the engine.
    DispatchQueue.main.async {
      self.runHeadlessEngine(
        bestAttemptContent: bestAttemptContent, contentHandler: contentHandler)
    }
  }

  private func runHeadlessEngine(
    bestAttemptContent: UNMutableNotificationContent,
    contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    // Initialise a headless FlutterEngine, and start executing Dart code
    // using a custom entrypoint.
    //
    // See docs:
    //   https://api.flutter.dev/ios-embedder/interface_flutter_engine.html#a4f74d860f311cb1a6c30a6411ca8e8ff
    //   https://api.flutter.dev/ios-embedder/interface_flutter_engine.html#a2ae6940c35afbdc5e1088aa9c1b26bbd
    let headlessEngine = FlutterEngine(
      name: "zulip_headless",
      project: nil,
      allowHeadlessExecution: true
    )
    let started = headlessEngine.run(
      withEntrypoint: "iosNotificationServiceMain",
      libraryURI: "package:zulip/notifications/ios_service.dart"
    )
    if !started {
      contentHandler(bestAttemptContent)  // TODO(log)
      return
    }
    self.headlessEngine = headlessEngine

    IosNativeHostApiSetup.setUp(
      binaryMessenger: headlessEngine.binaryMessenger, api: IosNativeHostApiImpl())

    // Register Flutter plugins with the headless engine.
    GeneratedPluginRegistrant.register(with: headlessEngine)

    let iosNotifFlutterApi = IosNotifFlutterApi(
      binaryMessenger: headlessEngine.binaryMessenger
    )

    iosNotifFlutterApi.didReceivePushNotification(
      content: NotificationContent(payload: bestAttemptContent.userInfo)
    ) { result in
      switch result {
      case .success(let improvedNotificationContent):
        bestAttemptContent.title = improvedNotificationContent.title
        bestAttemptContent.subtitle = improvedNotificationContent.subtitle
        bestAttemptContent.body = improvedNotificationContent.body
        bestAttemptContent.userInfo = improvedNotificationContent.userInfo as [AnyHashable : Any]
        contentHandler(bestAttemptContent)

      case .failure(let error):  // TODO(log)
        self.logger.debug(
          "IosNotifFlutterApi.didReceivePushNotification failed: \(error.localizedDescription)")
        contentHandler(bestAttemptContent)
      }

      // Tear down only after this callback has returned to the engine.
      DispatchQueue.main.async {
        self.headlessEngine?.destroyContext()
        self.headlessEngine = nil
      }
    }
  }

  /// Called by iOS when the `didReceive(_:withContentHandler:)` method doesn't
  /// call `contentHandler()` within a certain time limit (docs say 30 seconds).
  ///
  /// See docs: https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension/serviceextensiontimewillexpire()
  override func serviceExtensionTimeWillExpire() {
    if let contentHandler = contentHandler,
      let bestAttemptContent = bestAttemptContent
    {
      contentHandler(bestAttemptContent)  // TODO(log)
    }
  }
}
