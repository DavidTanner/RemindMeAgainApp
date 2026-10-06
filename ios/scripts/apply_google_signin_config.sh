#!/bin/sh
# Xcode build phase: copy the Google Sign-In client ID from the Flutter
# dart-defines (env.json via --dart-define-from-file, or --dart-define) into the
# processed Info.plist inside the app bundle, before code signing.
#
# ios/Runner/Info.plist references $(GOOGLE_IOS_CLIENT_ID) and
# $(GOOGLE_IOS_REVERSED_CLIENT_ID) as Xcode build settings, which Flutter never
# sets. Flutter does hand every dart-define to Xcode as DART_DEFINES: a
# comma-separated list of base64-encoded KEY=VALUE entries. This script decodes
# that list, derives the reversed client ID, and patches the two plist keys.
set -eu

plist="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
client_id=""

if [ -n "${DART_DEFINES:-}" ]; then
  old_ifs="$IFS"
  IFS=','
  for entry in $DART_DEFINES; do
    decoded=$(printf '%s' "$entry" | base64 --decode 2>/dev/null || true)
    case "$decoded" in
      GOOGLE_IOS_CLIENT_ID=*) client_id="${decoded#GOOGLE_IOS_CLIENT_ID=}" ;;
    esac
  done
  IFS="$old_ifs"
fi

if [ -z "$client_id" ]; then
  echo "warning: GOOGLE_IOS_CLIENT_ID is empty (see env.json); Google Sign-In will not work on iOS unless GOOGLE_IOS_CLIENT_ID and GOOGLE_IOS_REVERSED_CLIENT_ID are set as Xcode build settings."
  exit 0
fi

# 123-abc.apps.googleusercontent.com -> com.googleusercontent.apps.123-abc
reversed_client_id=$(printf '%s' "$client_id" | awk -F. '{ for (i = NF; i > 0; i--) printf "%s%s", $i, (i > 1 ? "." : "") }')

/usr/libexec/PlistBuddy -c "Set :GIDClientID $client_id" "$plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleURLTypes:0:CFBundleURLSchemes:0 $reversed_client_id" "$plist"
echo "Applied GOOGLE_IOS_CLIENT_ID from dart-defines to $plist"
