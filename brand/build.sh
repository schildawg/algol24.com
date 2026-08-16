#!/bin/sh
# Renders every Algol-24 brand asset from the SVG masters in svg/.
#
# Two rasterisers, because neither does the whole job on a stock macOS box:
#
#   ImageMagick  keeps alpha, and mis-renders SVG gradients (its built-in MSVG
#                delegate fills them flat black).  Used for the flat tiers.
#   qlmanage     renders gradients correctly through WebKit, and composites onto
#                white with no way to ask for transparency.  Used for the
#                gradient tiers, against an explicit background painted into a
#                temporary SVG wrapper.
#
# ⚠️ Installing librsvg (`brew install librsvg`) makes both halves unnecessary:
# `rsvg-convert` keeps alpha and renders gradients.  Collapse this script the
# day it is available on the build machine.

set -e
cd "$(dirname "$0")"

OUT=dist
INK='#00153D'
mkdir -p "$OUT" tmp

flat () {   # flat SVG -> transparent PNG at a size
    magick -background none "svg/$1.svg" -resize "${2}x${2}" "$OUT/$3"
}

onbg () {   # gradient SVG -> opaque PNG at a size, over a background colour
    # ⚠️ Algol C is near-black.  Against the dark ground it has to be lifted, or
    # the third star of a triple system is simply missing from the mark.
    if [ "$3" = "$INK" ]; then
        sed -e "s|<svg |<svg style=\"background:$3\" |" \
            -e "s|\.third { fill: #00153D; }|.third { fill: #C7D4E6; }|" \
            "svg/$1.svg" > "tmp/$1-bg.svg"
    else
        sed "s|<svg |<svg style=\"background:$3\" |" "svg/$1.svg" > "tmp/$1-bg.svg"
    fi
    rm -f "tmp/$1-bg.svg.png"
    qlmanage -t -s "$2" -o tmp "tmp/$1-bg.svg" >/dev/null 2>&1
    magick "tmp/$1-bg.svg.png" -resize "${2}x${2}!" "$OUT/$4"
}

echo "favicons — micro tier, transparent"
flat algol-24-micro 16 favicon-16.png
flat algol-24-micro 32 favicon-32.png
flat algol-24-micro 48 favicon-48.png
magick "$OUT/favicon-16.png" "$OUT/favicon-32.png" "$OUT/favicon-48.png" "$OUT/favicon.ico"

echo "app icons — compact tier, opaque as the platforms require"
onbg algol-24-compact 180 white apple-touch-icon.png
onbg algol-24-compact 192 white icon-192.png
onbg algol-24-full    512 white icon-512.png
onbg algol-24-full    512 "$INK" icon-512-dark.png

echo "maskable — mark inside the 80% safe zone"
magick "$OUT/icon-512.png" -resize 78% -background white -gravity center -extent 512x512 "$OUT/maskable-512.png"

echo "social card — 1200x630"
onbg algol-24-full 512 white tmp-og.png
magick "$OUT/tmp-og.png" -resize 420x420 -background white -gravity center -extent 1200x630 "$OUT/og-image.png"
rm -f "$OUT/tmp-og.png"

echo "web logos — SVG is the deliverable; PNG fallbacks only"
flat algol-24-micro   256 logo-glyph-256.png
onbg algol-24-full    512 white logo-512.png
cp svg/*.svg "$OUT/"

rm -rf tmp
echo
echo "wrote:"
ls -1 "$OUT"
