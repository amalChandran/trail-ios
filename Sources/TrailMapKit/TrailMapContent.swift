import SwiftUI
import MapKit
import TrailCore
import TrailUI

/// Native map primitives. Place inside Map { }; attach .trailPlayback(playback) to the Map.
/// Pan/zoom transforms are applied by MapKit, not by a second screen-overlay clock.
@MainActor public struct TrailMapContent: MapContent {
    private let strokes: [TrailMapStroke]
    public init(geometry: TrailMapGeometry, playback: TrailPlayback, unitsPerPoint: Double = 1, reducedMotion: Bool = false) {
        strokes = playback.player.effect.layers.enumerated().flatMap { index, layer in
            geometry.strokes(layer: layer, state: playback.frame(layer: index, reducedMotion: reducedMotion), unitsPerPoint: unitsPerPoint)
        }
    }
    public var body: some MapContent {
        ForEach(strokes.indices, id: \.self) { index in
            NativeStroke(stroke: strokes[index])
        }
    }
}
@MainActor private struct NativeStroke: MapContent {
    let stroke: TrailMapStroke
    private var coordinates: [CLLocationCoordinate2D] {
        stroke.coordinates.map { c in
            CLLocationCoordinate2D(latitude: c.latitude, longitude: max(-180.0 + 1e-7,min(180.0 - 1e-7,c.longitude)))
        }
    }
    public var body: some MapContent {
        MapPolyline(coordinates: coordinates)
            .stroke(stroke.color.mapColor, style: StrokeStyle(lineWidth: CGFloat(stroke.width),
                lineCap: stroke.roundCap ? .round : .butt, lineJoin: .round,
                dash: stroke.dash.map { CGFloat($0) }, dashPhase: CGFloat(stroke.dashPhase)))
    }
}
private extension TrailColor {
    var mapColor: Color { Color(.sRGB, red: Double((argb >> 16) & 255) / 255,
        green: Double((argb >> 8) & 255) / 255, blue: Double(argb & 255) / 255, opacity: Double(argb >> 24) / 255) }
}
