#!/usr/bin/env bash
set -e

IPA_PATH="${1:-./artifacts/Shuggr.ipa}"      # path to IPA
DYLIB_PATH="${2:-./artifacts/Tweak.dylib}"    # path to .dylib produced by Theos
APP_NAME="Shuggr"                            # اسم التطبيق (اسم الـ binary داخل .app)
WORKDIR="./work"

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
unzip -q "$IPA_PATH" -d "$WORKDIR"

APPDIR=$(find "$WORKDIR/Payload" -maxdepth 1 -type d -name "*.app" | head -n1)
if [ -z "$APPDIR" ]; then
  echo "App not found in IPA!"
  exit 1
fi

echo "App dir: $APPDIR"

# ensure Frameworks dir
mkdir -p "$APPDIR/Frameworks"
cp "$DYLIB_PATH" "$APPDIR/Frameworks/"

APPBIN="$APPDIR/$APP_NAME"

# add rpath
/usr/bin/install_name_tool -add_rpath "@executable_path/Frameworks" "$APPBIN" || true

# build insert_dylib if not present
if [ ! -f tools/insert_dylib ]; then
  echo "Building insert_dylib..."
  git clone https://github.com/Tyilo/insert_dylib.git /tmp/insert_dylib || true
  (cd /tmp/insert_dylib && make || true)
  cp /tmp/insert_dylib/insert_dylib tools/ || true
fi
chmod +x tools/insert_dylib

# inject
tools/insert_dylib --all-yes @rpath/$(basename "$DYLIB_PATH") "$APPBIN"

# optional sign with ldid
if command -v ldid >/dev/null 2>&1; then
  ldid -S "$APPBIN" || true
  ldid -S "$APPDIR/Frameworks/$(basename "$DYLIB_PATH")" || true
  echo "Signed with ldid"
else
  echo "ldid not found — skipping signing"
fi

# repackage
pushd "$WORKDIR" >/dev/null
zip -r ../Injected.ipa Payload -q
popd >/dev/null
echo "Injected IPA => Injected.ipa"
