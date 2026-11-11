#!/bin/bash
# SkirlField app — one-time project setup on macOS / Linux.   Run:  bash setup.sh
set -e
cd "$(dirname "$0")"

echo "1/5  Checking Flutter..."
flutter --version

if [ ! -d android ]; then
  echo "2/5  Creating Android and iOS project files..."
       flutter create --org com.softskirl --project-name skirlfield_app --platforms android,ios .

echo "3/5  Adding GPS permissions to AndroidManifest.xml..."
M=android/app/src/main/AndroidManifest.xml
if ! grep -q ACCESS_FINE_LOCATION "$M"; then
  perl -0pi -e 'BEGIN{local $/; open F,"platform/android-permissions.xml"; $p=<F>; close F} s/(<manifest[^>]*>)/$1\n$p/' "$M"
fi
if ! grep -q android.intent.action.DIAL "$M"; then
  perl -0pi -e 'BEGIN{local $/; open F,"platform/android-queries.xml"; $q=<F>; close F} s#</manifest>#$q\n</manifest>#' "$M"
fi
perl -pi -e 's/android:label="[^"]*"/android:label="SkirlField"/' "$M"

if [ "$(uname)" = "Darwin" ] && [ -f ios/Runner/Info.plist ]; then
  echo "4/5  Adding location keys to ios/Runner/Info.plist..."
  P=ios/Runner/Info.plist
  PB=/usr/libexec/PlistBuddy
  set_key() { $PB -c "Set :$1 $2" "$P" 2>/dev/null || $PB -c "Add :$1 string $2" "$P"; }
  set_key CFBundleDisplayName "SkirlField"
  set_key NSLocationWhenInUseUsageDescription "SkirlField records your route while you are on duty to calculate distance and travel allowance."
  set_key NSLocationAlwaysAndWhenInUseUsageDescription "SkirlField keeps recording your duty route when the app is in the background. Tracking stops when you end duty."
  set_key NSLocationAlwaysUsageDescription "SkirlField keeps recording your duty route when the app is in the background. Tracking stops when you end duty."
  $PB -c "Delete :UIBackgroundModes" "$P" 2>/dev/null || true
  $PB -c "Add :UIBackgroundModes array" "$P"
  $PB -c "Add :UIBackgroundModes:0 string location" "$P"
  $PB -c "Add :UIBackgroundModes:1 string fetch" "$P"
else
  echo "4/5  Not on a Mac: skipping iOS settings (run this script again on the Mac that builds iOS)"
fi

echo "5/5  Downloading packages..."
flutter pub get
echo
echo "Done. Android:  flutter run --release   |   flutter build apk --release"
echo "      iOS:      open ios/Runner.xcworkspace, set your Team under Signing, then flutter run --release"
