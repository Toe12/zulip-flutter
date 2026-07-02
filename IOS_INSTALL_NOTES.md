# Installing the app on a physical iPhone (runbook)

Project-specific notes for building & running this app on a real iPhone.
Values below are already configured in the repo.

| Setting | Value | Where |
|---|---|---|
| Apple Team | `3FR6H53LJ7` (Polaris Logistics Inc., paid) | `ios/Flutter/Zulip.xcconfig` |
| Bundle id | `com.wecare.zulip` (+ `.NotificationService`) | `ios/Runner.xcodeproj/project.pbxproj` |
| App Group | `group.com.wecare.zulip` | `ios/Flutter/Zulip.xcconfig` + `lib/model/store.dart` |
| Flutter | `/Users/toearkar/develop/flutter/bin/flutter` | |

## One-time setup (already done — only redo on a new Mac/account)

1. **Add Apple ID to Xcode**: Xcode → Settings → Accounts → ＋ → Apple ID (the paid one).
2. **Signing**: targets use Automatic signing with team `3FR6H53LJ7`. Already set in `Zulip.xcconfig`.
3. **Developer Mode on the iPhone** (iOS 16+):
   Settings → Privacy & Security → Developer Mode → On → **restart** → after reboot tap "Turn On".
   (The menu item only appears after a first install attempt from Xcode/flutter.)
4. **Trust**: first time, unlock phone and tap "Trust This Computer".

## Every-time: build & run

```bash
cd /Users/toearkar/coding_project/wecare/zulip-flutter

# find the device id (look for your iPhone, not the simulator)
/Users/toearkar/develop/flutter/bin/flutter devices

# run on it (current device id shown below; re-check if it changes)
/Users/toearkar/develop/flutter/bin/flutter run -d 00008150-000D38593C04401C
```

- First build is slow (pod install + full Xcode build, ~2 min). Later builds are fast.
- If it says **"Developer Mode disabled"** → finish step 3 above.
- If **code signing** fails → confirm the Apple ID is added in Xcode and the team in
  `Zulip.xcconfig` matches an account you're signed into.

### "Flutter could not access the local network"
macOS privacy prompt. System Settings → Privacy & Security → Local Network → enable your
terminal app. The app still installs; this only affects the live log/hot-reload connection.

### Success check (notifications)
In the run log you must see a **non-null** APNs token:
```
flutter: notif APNs token: <hex>     # null only on the simulator
```

## Known limitation: the dev server is not reachable from the phone

The Zulip dev server listens on `127.0.0.1:9991` (inside Docker/Vagrant). A physical iPhone
cannot reach the Mac's `localhost`, so the app shows connection errors for `localhost:9991`.

To connect a real phone you must expose the server and set `EXTERNAL_HOST`:
- **Tunnel** (recommended): run a tunnel (ngrok/cloudflared) to `127.0.0.1:9991`, set
  `EXTERNAL_HOST` to its public HTTPS host, restart the server, add the account in the app
  using that URL.
- **LAN** (`192.168.1.126`): expose Docker/Vagrant port 9991 on the LAN, set
  `EXTERNAL_HOST=192.168.1.126:9991`, restart; phone must be on the same Wi-Fi.

Changing `EXTERNAL_HOST` changes the realm URL — coordinate with the Android push setup in
`../zulip/LOCAL_MOBILE_PUSH_NOTIFICATION_NOTES.md`.

## To actually receive push notifications (server side)

The server also needs APNs credentials (currently missing):
- Put your APNs auth key at `../zulip/zproject/apns-dev-key.p8`
- `../zulip/zproject/dev-secrets.conf` already has `apns_token_key_id` and `apns_team_id`
- `APNS_SANDBOX = True` is set (correct for development-signed builds)
- Restart the server. `has_apns_credentials()` then returns True.

## App Check debug token (per device/install)

App Check uses the debug provider. Each device/install has its own debug token. To stop the
`appcheck apailed` 403 noise on a new device:
1. Get the token from the device log:
   `xcrun simctl spawn booted log show --last 5m --style compact | grep -i "debug token"`
   (on a real device, read it via Console.app / Xcode console)
2. Firebase Console → project `app-check-demo-cb9da` → App Check → iOS app
   `...ios:a9bdcc9bd933031cdcc2b0` → Manage debug tokens → add it.
App Check failing is non-fatal — requests still succeed without the header.

## Testing notification UI on the Simulator (no real push)

The simulator can't get an APNs token, but you can inject a local notification to test display:
```bash
xcrun simctl terminate booted com.wecare.zulip   # ensure not foreground
xcrun simctl push booted com.wecare.zulip /tmp/zulip_test.apns
```
Example `/tmp/zulip_test.apns`:
```json
{ "Simulator Target Bundle": "com.wecare.zulip",
  "aps": { "alert": { "title": "Test", "body": "Hello" }, "sound": "default", "badge": 1 } }
```
