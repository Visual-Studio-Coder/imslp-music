#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
platform="${1:-mac}"
stamp="$(date +%Y%m%d-%H%M%S)"
mkdir -p Artifacts
case "$platform" in
  mac)
    scheme=IMSLPMusicMac
    destination='platform=macOS'
    derived=build/mac
    ;;
  iphone|ipad)
    scheme=IMSLPMusicMobile
    derived=build/mobile
    if [ "$platform" = iphone ]; then
      device_name='IMSLP iPhone'
    else
      device_name='IMSLP iPad'
    fi
    destination="platform=iOS Simulator,name=$device_name"
    ;;
  *) echo 'Usage: Scripts/test.sh mac|iphone|ipad'; exit 2 ;;
esac
result="Artifacts/$platform-$stamp.xcresult"
xcodebuild -project IMSLPMusic.xcodeproj -scheme "$scheme" \
  -configuration Debug -destination "$destination" -derivedDataPath "$derived" \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -resultBundlePath "$result" test 2>&1 | tee "Artifacts/$platform-$stamp.log"
xcrun xcresulttool export attachments --path "$result" --output-path "Artifacts/$platform-$stamp-screens"
echo "Test evidence: $result"
