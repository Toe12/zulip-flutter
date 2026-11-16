# Universal Links (iOS)

Tapping a link like `https://basecomms.com/#narrow/channel/7-general`
in Messages, Mail, Notes, etc. can open this app instead of Safari.
Two halves have to agree:

- **The app** claims the domain (the `applinks:` entitlement) and routes
  the link it is handed (`lib/widgets/app_link.dart`).
- **The server** vouches for the app, by serving an
  `apple-app-site-association` (AASA) file at
  `https://basecomms.com/.well-known/apple-app-site-association`.

The app half is in this repo.  The server half is deployed on
basecomms.com, as described below.

## Server

### `apple-app-site-association`

Install at `/var/www/basecomms/apple-app-site-association`
(no `.json` extension).

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["3FR6H53LJ7.com.basecomms.app"],
        "components": [
          {
            "/": "/",
            "#": "narrow*",
            "comment": "Only links into a narrow open the app."
          },
          {
            "/": "/login/",
            "#": "narrow*",
            "comment": "The same, as copied from a logged-out browser."
          }
        ]
      }
    ]
  }
}
```

- App ID is `<Team ID>.<bundle id>`.
- Only `/#narrow/…` (and the same after `/login/`) is claimed: other login,
  help-center and settings pages stay in the browser.  The app also ignores
  anything else it is handed.
- `"#"` fragment matching is supported on iOS 14 and later.  This has not
  been tried on a device.  If the fragment is not matched, fix the
  pattern rather than widening it to all of `/`: the app does not
  forward a link it declines on to the browser, so a wider rule would
  turn taps on other root-page links into dead ends.

### nginx

Add `/etc/nginx/zulip-include/app.d/aasa.conf`, beside the existing
`assetlinks.conf` (Android App Links) and written in the same style:

```nginx
location = /.well-known/apple-app-site-association {
    alias /var/www/basecomms/apple-app-site-association;
    default_type application/json;
    add_header Cache-Control "public, max-age=3600";
}
```

Requirements from Apple: HTTPS with a valid certificate, status 200
with no redirect, `application/json`, no authentication, under 128 KB.

Check after deploying:

```bash
curl -sI https://basecomms.com/.well-known/apple-app-site-association
curl -s  https://basecomms.com/.well-known/apple-app-site-association | python3 -m json.tool
```

and run `sudo nginx -t` before reloading.

## App side

- `ios/Runner/Runner.entitlements` declares `applinks:basecomms.com`.
  For a development build you may append `?mode=developer` to the domain
  and enable *Settings → Developer → Associated Domains Development*
  on the device, so the system reads the AASA straight from the server
  instead of via Apple's CDN cache.
- The App ID in the Apple developer portal must have the *Associated
  Domains* capability enabled, and the provisioning profile regenerated.
- `lib/widgets/app.dart` hands the link to `AppLink`, whether it launched
  the app (initial route) or arrived while running (route information).
- `AppLink` opens a link only if it is `http(s)` to the root (or `/login/`)
  with a `#narrow/…` fragment, including `#narrow/id/<message id>`,
  and its origin matches the realm of one of the user's accounts; it
  switches to that account if needed, waits for the account's data,
  then pushes the narrow.

## Pasted links: the `basecomms://` scheme

A link typed or pasted into a browser's address bar is never handed to
an app, whatever the AASA says.  So the web app (`web/src/open_in_app.ts`
in the server repo) sends a phone's browser that loads a `#narrow` page on
to the same link with this app's own scheme, once per link per tab:

    https://basecomms.com/#narrow/id/488  ->  basecomms://basecomms.com/#narrow/id/488

The scheme is registered in `ios/Runner/Info.plist` and
`android/app/src/main/AndroidManifest.xml`.  `AppLink` maps such a link back
to the `https` one and then treats it like any other, so the same checks
apply: an account on that realm, and a narrow.  On iOS, Safari asks
"Open in BaseComms?" the first time.  Without the app installed, the
browser shows a "cannot open" notice, and the web app stays loaded.

## Testing on a device

Universal Links cannot be tried in the simulator against a real domain
reliably, and typing the URL in Safari never opens the app.  On a device:

1. Install a build with the entitlement, once the AASA is live.
2. Put the link in Notes or Messages and tap it
   (long-press → *Open in BaseComms* if it went to Safari).
3. Cold start (app killed) and warm (app running) are separate paths;
   try both, with the link's account both current and not current.

Apple caches the AASA through its CDN, so a change can take a while to
reach devices; `?mode=developer` bypasses that.

Not yet verified on a device: fragment matching, and how the link is
reported on cold start (as a full URL or as a path).

## Android

Not wired up.  The server already serves `assetlinks.json`, but
`AndroidManifest.xml` has no `https` intent filter with
`android:autoVerify="true"`, so links still open in the browser.
