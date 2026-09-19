#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"
TRAIL_PROBE="$TRAIL_ROOT/artifacts/ios-size-probe"
TRAIL_PACKAGE="$TRAIL_ROOT/swift"
[[ -f "$TRAIL_ROOT/Package.swift" ]] && TRAIL_PACKAGE="$TRAIL_ROOT"
export TRAIL_PROBE TRAIL_PACKAGE
python3 - <<'PY'
from pathlib import Path
import os
p=Path(os.environ['TRAIL_PROBE']);p.mkdir(parents=True,exist_ok=True)
(p/'project.yml').write_text('''name: TrailSizeProbe
packages:
  Trail:
    path: '''+os.environ['TRAIL_PACKAGE']+'''
settings:
  base:
    SWIFT_VERSION: "6.0"
    IPHONEOS_DEPLOYMENT_TARGET: "17.0"
    GENERATE_INFOPLIST_FILE: YES
    CODE_SIGNING_ALLOWED: NO
    DEAD_CODE_STRIPPING: YES
    SWIFT_COMPILATION_MODE: wholemodule
targets:
  MapBase:
    type: application
    platform: iOS
    sources: [MapBase.swift]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: dev.trail.sizeprobe.base
  MapTrail:
    type: application
    platform: iOS
    sources: [MapTrail.swift]
    dependencies:
      - package: Trail
        product: TrailMapKit
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: dev.trail.sizeprobe.trail
''')
(p/'MapBase.swift').write_text('''import SwiftUI
import MapKit
@main struct App: SwiftUI.App {
 var body: some Scene { WindowGroup { Map {
  MapPolyline(coordinates: [CLLocationCoordinate2D(latitude: 40,longitude: -73),CLLocationCoordinate2D(latitude: 40.01,longitude: -72.99)]).stroke(.blue,lineWidth: 6)
 } } }
}
''')
(p/'MapTrail.swift').write_text('''import SwiftUI
import TrailCore
import TrailMapKit
@main struct App: SwiftUI.App {
 let route = try! TrailRoute.direct(id: "route",from: TrailCoordinate(latitude: 40,longitude: -73),to: TrailCoordinate(latitude: 40.01,longitude: -72.99))
 let effect = TrailEffect { Stroke(.blue,width: 6); Reveal(duration: .seconds(2)) }
 var body: some Scene { WindowGroup { TrailMap(route: route,effect: effect) } }
}
''')
PY
TRAIL_XCODEGEN="$(command -v xcodegen || true)"
[[ -n "$TRAIL_XCODEGEN" ]] || TRAIL_XCODEGEN=/opt/homebrew/bin/xcodegen
(cd "$TRAIL_PROBE" && "$TRAIL_XCODEGEN" generate)
for TRAIL_SCHEME in MapBase MapTrail; do
  xcodebuild -project "$TRAIL_PROBE/TrailSizeProbe.xcodeproj" -scheme "$TRAIL_SCHEME" -configuration Release \
    -destination 'generic/platform=iOS' -derivedDataPath "$TRAIL_PROBE/build" CODE_SIGNING_ALLOWED=NO build -quiet
done
python3 - <<'PY'
from pathlib import Path
import os,json
p=Path(os.environ['TRAIL_PROBE']);products=p/'build/Build/Products/Release-iphoneos'
r={name:(products/f'{name}.app'/name).stat().st_size for name in ('MapBase','MapTrail')}
r['incremental_macho_bytes']=r['MapTrail']-r['MapBase'];r['conditions']='Unsigned arm64 iPhoneOS Release executables, dead stripping. Two-point reveal, not all catalog features; not App Store download/installed size.'
(p/'size.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
PY
