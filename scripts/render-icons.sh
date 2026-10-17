#!/usr/bin/env bash
# Render favicons, app icons and the social card from the SVG sources.
#   static/img/logo.svg  -> favicon.ico, favicon.png, icon-192.png, icon-512.png
#   (square variant)     -> apple-touch-icon.png, icon-maskable-512.png
#   art/og-image.svg     -> static/img/og-image.png
# Needs Inkscape and ImageMagick (brew install --cask inkscape; brew install imagemagick).
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

render() { inkscape "$1" -w "$2" -h "$3" -o "$4" 2>/dev/null; }

# Rounded tile: favicons and "any" icons
render static/img/logo.svg 16 16 "$tmp/16.png"
render static/img/logo.svg 32 32 "$tmp/32.png"
render static/img/logo.svg 48 48 "$tmp/48.png"
cp "$tmp/32.png" static/favicon.png
magick "$tmp/16.png" "$tmp/32.png" "$tmp/48.png" static/favicon.ico
render static/img/logo.svg 192 192 static/icon-192.png
render static/img/logo.svg 512 512 static/icon-512.png

# Square, full-bleed: iOS and Android mask the corners themselves
sed -e 's/<rect width="64" height="64" rx="14" fill="#1e1433"\/>/<rect width="64" height="64" fill="#1e1433"\/>/' \
    -e 's/<clipPath id="refrakt-tile"><rect width="64" height="64" rx="14"\/>/<clipPath id="refrakt-tile"><rect width="64" height="64"\/>/' \
    static/img/logo.svg > "$tmp/square.svg"
render "$tmp/square.svg" 180 180 static/apple-touch-icon.png
# Maskable: keep the mark inside the 80% safe zone
render "$tmp/square.svg" 400 400 "$tmp/mask-inner.png"
magick -size 512x512 xc:'#1e1433' "$tmp/mask-inner.png" -gravity center -composite static/icon-maskable-512.png

render art/og-image.svg 1200 630 static/img/og-image.png
echo "Icons rendered."
