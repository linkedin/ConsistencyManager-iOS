#!/bin/sh
# Builds all targets and runs tests.

DERIVED_DATA=${1:-/tmp/ConsistencyManager}
echo "Derived data location: $DERIVED_DATA";

set -o pipefail &&
rm -rf $DERIVED_DATA &&
time xcodebuild clean test \
    -scheme ConsistencyManager \
    -sdk macosx \
    -enableCodeCoverage YES
    -derivedDataPath $DERIVED_DATA \
    | tee build.log \
    | xcpretty &&
rm -rf $DERIVED_DATA &&
time xcodebuild clean test \
    -scheme ConsistencyManager \
    -sdk iphonesimulator \
    -disable-concurrent-destination-testing \
    -derivedDataPath $DERIVED_DATA \
    -destination 'platform=iOS Simulator,name=iPhone 6,OS=10.3.1' \
    -destination 'platform=iOS Simulator,name=iPhone 7,OS=11.4' \
    -destination 'platform=iOS Simulator,name=iPhone X,OS=12.4' \
    -destination 'platform=iOS Simulator,name=iPhone 11 Pro,OS=13.3' \
    | tee build.log \
    | xcpretty &&
rm -rf $DERIVED_DATA &&
time xcodebuild clean test \
    -scheme ConsistencyManager \
    -sdk appletvsimulator \
    -derivedDataPath $DERIVED_DATA \
    -destination 'platform=tvOS Simulator,name=Apple TV,OS=13.3' \
    | tee build.log \
    | xcpretty &&
cat build.log
