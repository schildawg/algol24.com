#!/bin/sh
# Builds the site into site/.
#
#   ./build.sh            # generate
#   ./build.sh --test     # run the generator's own test blocks
#
# Needs algc. If vendor/algol24 has not been built, this builds it -- which
# needs nothing but a C compiler, because the compiler's own output is checked
# in to bootstrap/.

set -e
cd "$(dirname "$0")"

# ⚠️ Both of these live under bootstrap/. The compiler repository moved them
# there, and the commit this submodule used to pin no longer exists on the
# remote -- CI failed on the checkout, not on the build. Keep this in step with
# the same two paths in .github/workflows/deploy.yml.
ALGC=vendor/algol24/bootstrap/algc

if [ ! -x "$ALGC" ]; then
    echo "algc not built; building the compiler first"
    ( cd vendor/algol24 && ./bootstrap/build.sh )
fi

if [ "${1-}" = "--test" ]; then
    exec "$ALGC" --test gen/Main.a24
fi

# ⚠️ The language cannot create a directory, so the output tree has to exist
# before the generator runs. This is the workaround that stops working the day
# the tree is decided by the content -- see WISHLIST-SITEGEN.md.
mkdir -p site

"$ALGC" gen/Main.a24

cp -R static/. site/ 2>/dev/null || true
for f in favicon.ico favicon-16.png favicon-32.png apple-touch-icon.png \
         icon-192.png icon-512.png og-image.png; do
    [ -f "brand/dist/$f" ] && cp "brand/dist/$f" site/
done

# -I skips binaries: a PNG will contain the bytes '{{' sooner or later, and
# og-image.png duly did.
if grep -rnI '{{' site/ 2>/dev/null; then
    echo "FAIL  unrendered placeholder in the generated site"
    exit 70
fi

echo "site/ is ready"
