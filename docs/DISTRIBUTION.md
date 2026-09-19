# Install and release Trail for iOS

`2.0.0-alpha02` is a local release candidate. The public `amalChandran/trail-ios` repository and tag still need publication. GitHub CLI has no signed-in account in the preparation environment.

Use Xcode → Add Package Dependencies → Add Local → this repository now. The root `Package.swift` exposes **TrailMapKit**, **TrailUI**, **TrailEffects**, **TrailCore**, and the optional sample plugin. Pick only the products you use; there are no external package dependencies. Requires iOS 17+ / macOS 14+ and Swift tools 6.0.

After remote publication and tagging, add `https://github.com/amalChandran/trail-ios` in Xcode, or declare:

```swift
.package(url: "https://github.com/amalChandran/trail-ios", exact: "2.0.0-alpha02")
```

The sample app in `Examples/` consumes the root package as a separate Xcode project. `scripts/check.sh` validates generated examples, shared fixtures and Swift tests. `scripts/test-ios.sh` builds and runs native/UI tests. `scripts/release/measure-ios.sh` compares independently built device release consumers with and without Trail.

Before publishing a tag, verify a fresh clone, package resolution and the example app; run physical-device startup, gestures, accessibility and background/resume acceptance. Preserve dead stripping in consumers. Swift Package Index can be added after a public repository and tag exist. Binary XCFramework, CocoaPods and Carthage distribution are not part of this release.

Android stays in `amalChandran/trail-android` and uses Maven Central independently. No Kotlin binary or runtime is included here. Shared fixture schema 1 and vector fixtures are checked into each repository; coordinate semantic changes across releases.

No signing keys, account credentials or map-service secrets belong in Git. The local build and measurement scripts do not publish anything.
