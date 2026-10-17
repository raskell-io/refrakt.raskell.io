#!/usr/bin/env bash
# Render favicons, app icons and the social card from the SVG sources.
#   static/img/logo.svg  -> favicon.ico, favicon.png, icon-192.png, icon-512.png
#                           apple-touch-icon.png, icon-maskable-512.png
#   art/og-image.svg     -> static/img/og-image.png
# Needs Inkscape and ImageMagick (brew install --cask inkscape; brew install imagemagick).
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

render() { inkscape "$1" -w "$2" -h "$3" -o "$4" 2>/dev/null; }

# Favicons and "any" icons: the bare crystal on a transparent background
render static/img/logo.svg 16 16 "$tmp/16.png"
render static/img/logo.svg 32 32 "$tmp/32.png"
render static/img/logo.svg 48 48 "$tmp/48.png"
cp "$tmp/32.png" static/favicon.png
magick "$tmp/16.png" "$tmp/32.png" "$tmp/48.png" static/favicon.ico
render static/img/logo.svg 192 192 static/icon-192.png
render static/img/logo.svg 512 512 static/icon-512.png

# iOS and Android want an opaque square and mask the corners themselves.
# The crystal sits on the light page colour; maskable keeps it inside the 80% safe zone.
render static/img/logo.svg 128 128 "$tmp/touch.png"
magick -size 180x180 xc:'#f8f9fd' "$tmp/touch.png" -gravity center -composite static/apple-touch-icon.png
render static/img/logo.svg 300 300 "$tmp/mask.png"
magick -size 512x512 xc:'#f8f9fd' "$tmp/mask.png" -gravity center -composite static/icon-maskable-512.png

render art/og-image.svg 1200 630 static/img/og-image.png
echo "Icons rendered."
