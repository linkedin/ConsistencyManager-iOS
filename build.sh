#!/bin/sh

# macOS
set -o pipefail &&
time xcodebuild clean test \
    -scheme ConsistencyManager \
    -sdk macosx \
| xcpretty

# tvOS
set -o pipefail &&
time xcodebuild clean test \
    -scheme ConsistencyManager \
    -destination 'platform=tvOS Simulator,name=Apple TV,OS=13.3' \
| xcpretty

# iOS
set -o pipefail &&
time xcodebuild clean test \
    -scheme ConsistencyManager \
    -destination 'platform=iOS Simulator,name=iPhone 6,OS=10.3.1' \
    -destination 'platform=iOS Simulator,name=iPhone 7,OS=11.4' \
    -destination 'platform=iOS Simulator,name=iPhone X,OS=12.2' \
    -destination 'platform=iOS Simulator,name=iPhone 11 Pro,OS=13.3' \
| xcpretty
