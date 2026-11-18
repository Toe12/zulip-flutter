#!/usr/bin/env bash
#
# Generate the App Store screenshots, ready to upload.
#
#   tool/app_store_screenshots/generate.sh [output-dir]
#
# Writes eight PNG files (four screens, for the 6.9-inch iPhone and the
# 13-inch iPad) to build/app_store_screenshots/, or to `output-dir`.
# See app_store_screenshots_test.dart for how the screens are drawn and
# how to change the sample data.
set -euo pipefail

cd "$(dirname "$0")/../.."
out="${1:-build/app_store_screenshots}"

rm -rf "$out"
SCREENSHOT_DIR="$out" flutter test tool/app_store_screenshots/app_store_screenshots_test.dart

# App Store Connect does not accept transparency, and Flutter's PNGs
# have an alpha channel even though every pixel is opaque.  Remove it.
flatten_with_pillow() {
  python3 - "$out" <<'PY'
import glob, sys
from PIL import Image
for path in sorted(glob.glob(sys.argv[1] + "/*.png")):
    Image.open(path).convert("RGB").save(path, optimize=True)
PY
}
flatten_with_imagemagick() {
  for path in "$out"/*.png; do
    magick "$path" -background white -alpha remove -alpha off "$path"
  done
}
if python3 -c "import PIL" 2>/dev/null; then
  flatten_with_pillow
elif command -v magick >/dev/null; then
  flatten_with_imagemagick
else
  echo "warning: install Pillow (pip3 install Pillow) or ImageMagick" >&2
  echo "         to remove the alpha channel; the files are otherwise fine." >&2
fi

echo
echo "Screenshots written to $out:"
for path in "$out"/*.png; do
  printf '  %s  %s\n' "$(basename "$path")" \
    "$(sips -g pixelWidth -g pixelHeight "$path" | awk '/pixel/ {printf "%s ", $2}')"
done
