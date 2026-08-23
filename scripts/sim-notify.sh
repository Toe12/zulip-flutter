#!/usr/bin/env bash
#
# sim-notify.sh — push a local test notification to the booted iOS Simulator.
#
# The iOS Simulator can't receive real APNs pushes, but `xcrun simctl push`
# injects a notification locally so you can test display + tap-to-open.
#
# Usage:
#   scripts/sim-notify.sh simple  "<title>" "<body>"
#   scripts/sim-notify.sh channel <stream_id> "<topic>" "<body>"
#   scripts/sim-notify.sh dm      "<body>"
#
# Examples:
#   scripts/sim-notify.sh simple  "Greg Price" "take a look"
#   scripts/sim-notify.sh channel 7 "new logo" "take a look at this"
#   scripts/sim-notify.sh dm "are you around?"
#
# Tap-to-open (channel/dm) only navigates correctly when REALM_URL / USER_ID /
# SENDER_ID / stream_id match the account logged in on the simulator.
# Override the defaults below via environment variables, e.g.:
#   USER_ID=26 SENDER_ID=28 REALM_URL=http://localhost:9991 \
#     scripts/sim-notify.sh channel 7 "new logo" "hi"

set -euo pipefail

# ---- config (override via env) ------------------------------------------------
BUNDLE_ID="${BUNDLE_ID:-com.basecomms.app}"
REALM_URL="${REALM_URL:-http://localhost:9991}"
USER_ID="${USER_ID:-26}"      # the account logged in on the simulator
SENDER_ID="${SENDER_ID:-28}"  # who the message is "from"
# -------------------------------------------------------------------------------

MODE="${1:-simple}"
PAYLOAD="$(mktemp /tmp/sim-notify.XXXXXX.apns)"
trap 'rm -f "$PAYLOAD"' EXIT

case "$MODE" in
  simple)
    TITLE="${2:-Zulip}"
    BODY="${3:-Test notification}"
    cat > "$PAYLOAD" <<JSON
{
  "Simulator Target Bundle": "$BUNDLE_ID",
  "aps": { "alert": { "title": "$TITLE", "body": "$BODY" }, "sound": "default", "badge": 1 }
}
JSON
    ;;

  channel)
    STREAM_ID="${2:?need <stream_id>}"
    TOPIC="${3:?need <topic>}"
    BODY="${4:-Test channel message}"
    cat > "$PAYLOAD" <<JSON
{
  "Simulator Target Bundle": "$BUNDLE_ID",
  "aps": { "alert": { "title": "#channel > $TOPIC", "body": "$BODY" }, "sound": "default", "badge": 1 },
  "zulip": {
    "event": "message",
    "recipient_type": "stream",
    "stream_id": $STREAM_ID,
    "topic": "$TOPIC",
    "realm_url": "$REALM_URL",
    "user_id": $USER_ID,
    "sender_id": $SENDER_ID
  }
}
JSON
    ;;

  dm)
    BODY="${2:-Test direct message}"
    cat > "$PAYLOAD" <<JSON
{
  "Simulator Target Bundle": "$BUNDLE_ID",
  "aps": { "alert": { "title": "Direct message", "body": "$BODY" }, "sound": "default", "badge": 1 },
  "zulip": {
    "event": "message",
    "recipient_type": "private",
    "realm_url": "$REALM_URL",
    "user_id": $USER_ID,
    "sender_id": $SENDER_ID
  }
}
JSON
    ;;

  *)
    echo "unknown mode: $MODE" >&2
    echo "usage: $0 {simple|channel|dm} ..." >&2
    exit 2
    ;;
esac

# Banners are hidden while the app is foreground, so background it first.
xcrun simctl terminate booted "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "Pushing ($MODE) to $BUNDLE_ID on booted simulator..."
xcrun simctl push booted "$BUNDLE_ID" "$PAYLOAD"
echo "Done. Check the simulator screen (tap the banner to test navigation)."
