# Native recording provenance

Captured 2026-09-20 from the actual iPhone 17 Pro / iOS 26.2 simulator app. `ios-flight.png`, `ios-cab.png` and `ios-ferry.png` are native UI-test attachments. `ios-loading-route.gif` comes from `xcrun simctl io … recordVideo` during the passing loading/morph/gesture test.

The GIF crops application chrome while retaining the Apple Maps attribution, downsizes to 480 pixels wide at 16 fps and holds its final real frame briefly. It is a visual demonstration, not a frame-rate benchmark. Original video is retained in the original Android preparation checkout’s ignored `artifacts/ios-native-loading.mp4`.

Run `scripts/release/verify-media.py` to verify that README GIFs exist and contain multiple frames.
