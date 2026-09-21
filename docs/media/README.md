# Native recording provenance

These are recordings of the actual SwiftUI / MapKit example app. Map attribution is retained.

| Asset | Journey / behavior | Recorded |
| --- | --- | --- |
| `ios-cab.gif` | Times Square → Grand Central, all 119 route points, top-down car turns with its heading | 2026-09-21 |
| `ios-ferry.gif` | Circular Quay → Manly, illustrative harbour path, top-down ferry | 2026-09-21 |
| `ios-flight.gif` | JFK → Heathrow, two-endpoint decorative arc, top-down aircraft | 2026-09-21 |
| `ios-loading-route.gif` | Travelling loading arc, delayed bundled response, 650 ms morph into the road route | 2026-09-20 |

## Recreate the journey loops

Build/install the debug example with `scripts/run-ios.sh`. For each of `flight`, `cab` and `ferry`, start `xcrun simctl io "$TRAIL_SIM" recordVideo --codec=h264 recording.mp4`, then launch with `xcrun simctl launch --terminate-running-process "$TRAIL_SIM" dev.trail.playground --trail-journey cab` (substitute the journey). Record at least two cycles; stop recording with SIGINT. The launch argument belongs to the debug example, not the SDK.

The 2026-09-21 recordings use an iPhone 17 Pro simulator at 1206×2622. A settled cycle is cropped to `1110:1300:48:640`, preserving the journey title, whole map, Apple attribution and point count, then scaled to 560 px wide at 16 fps. The flight/cab/ferry excerpts start at 19/21/24 seconds and last 16/18/20 seconds respectively. FFmpeg uses `palettegen=stats_mode=diff` and `paletteuse=dither=sierra2_4a`. Choose crop and timestamps again if the device or layout changes.

The loading GIF was recorded during the passing native loading/gesture UI flow. It is cropped to the map and loading controls and holds its last real frame briefly. The still PNGs are retained as supplemental screenshots; README journey previews use animated GIFs.

Original videos are kept in ignored `artifacts/`. Run `python3 scripts/release/verify-media.py` to check that referenced GIFs exist and contain multiple frames. These recordings explain behavior; their downsampled frame rate is not a performance benchmark.

Journey data and licensing: [samples](../../samples/README.md). Android recordings and native Google integration: [Trail for Android](https://github.com/amalChandran/trail-android).
