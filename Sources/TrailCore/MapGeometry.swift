import Foundation

/// Geographic position and clockwise-from-north bearing. Neither depends on the camera.
public struct TrailMapPose: Sendable, Equatable {
    public let coordinate: TrailCoordinate
    public let bearing: Double
}
public struct TrailMapStroke: Sendable, Equatable {
    public let coordinates: [TrailCoordinate]
    public let color: TrailColor
    public let width: Double
    public let dash: [Double]
    public let dashPhase: Double
    public let roundCap: Bool
}

/// Prepared Mercator geometry for native map content. Retain for the lifetime of a route.
public struct TrailMapGeometry: Sendable {
    public let route: TrailRoute
    public let path: TrailPath
    public init(_ route: TrailRoute) { self.route = route; path = route.project(Self.point) }
    public func pose(at fraction: Double, headingWindow: Double? = nil, direction: TrailDirection = .forward) -> TrailMapPose? {
        guard let pose = path.pose(at: fraction, headingWindow: headingWindow ?? path.length * 0.02, direction: direction) else { return nil }
        let bearing = pose.headingRadians * 180 / .pi + 90
        return TrailMapPose(coordinate: Self.coordinate(pose.point), bearing: (bearing.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360))
    }
    /// Dimensions are Apple points; unitsPerPoint is Mercator meters per display point.
    public func strokes(layer: TrailLayer, state: TrailVisualState, unitsPerPoint: Double) -> [TrailMapStroke] {
        precondition(unitsPerPoint.isFinite && unitsPerPoint > 0)
        guard path.length > 0, state.opacity > 0, state.widthScale > 0 else { return [] }
        var result: [TrailMapStroke] = []
        func add(_ points: [TrailPoint], color: TrailColor, width: Double, dash: [Double] = [], phase: Double = 0, cap: Bool = true) {
            for segment in TrailGeography.splitAtDateLine(points.map(Self.coordinate)) where segment.count > 1 {
                result.append(TrailMapStroke(coordinates: segment, color: color, width: width, dash: dash, dashPhase: phase, roundCap: cap))
            }
            precondition(result.count <= 8192, "Native map layer exceeds 8192 primitives; simplify style or windows")
        }
        for command in layer.commands {
            switch command {
            case .stroke(let stroke):
                for window in state.windows {
                    let start = max(stroke.start, window.start), end = min(stroke.end, window.end)
                    guard start < end, window.opacity > 0 else { continue }
                    let cycle = stroke.dash.reduce(0,+)
                    if start == 0, end == 1, cycle == 0 {
                        for segment in route.segments where segment.count > 1 {
                            result.append(TrailMapStroke(coordinates: segment, color: stroke.color.opacity(state.opacity * window.opacity),
                                width: stroke.width * state.widthScale, dash: [], dashPhase: 0, roundCap: stroke.roundCap))
                        }
                        continue
                    }
                    for slice in path.slices(from: start, to: end) {
                        add(slice.points, color: stroke.color.opacity(state.opacity * window.opacity), width: stroke.width * state.widthScale,
                            dash: stroke.dash, phase: cycle == 0 ? 0 : (slice.distanceFromStart / unitsPerPoint - state.dashPhase * cycle).truncatingRemainder(dividingBy: cycle), cap: stroke.roundCap)
                    }
                }
            case .chevrons(let stamp):
                let spacing = stamp.spacing * unitsPerPoint
                let count = Int(min(2048, floor(path.length / spacing)))
                for i in 0..<count {
                    let fraction = ((Double(i) + 0.5 + state.dashPhase) * spacing / path.length).truncatingRemainder(dividingBy: 1)
                    guard let window = state.windows.first(where: { fraction >= $0.start && fraction <= $0.end }), let pose = path.pose(at: fraction, headingWindow: 0) else { continue }
                    let half = stamp.size * state.widthScale * unitsPerPoint / 2
                    func transformed(_ x: Double, _ y: Double) -> TrailPoint {
                        TrailPoint(pose.point.x + x * cos(pose.headingRadians) - y * sin(pose.headingRadians),
                                   pose.point.y + x * sin(pose.headingRadians) + y * cos(pose.headingRadians))
                    }
                    add([transformed(-half,-half), transformed(half,0), transformed(-half,half)],
                        color: stamp.color.opacity(state.opacity * window.opacity), width: stamp.size * 0.25 * state.widthScale)
                }
            }
        }
        return result
    }
    public static let worldMeters = 40_075_016.68557849
    private static let radius = worldMeters / (2 * Double.pi)
    static func point(_ c: TrailCoordinate) -> TrailPoint {
        TrailPoint(c.longitude * .pi / 180 * radius, -TrailGeography.mercatorY(c.latitude) * radius)
    }
    static func coordinate(_ p: TrailPoint) -> TrailCoordinate {
        TrailGeography.coordinate(max(-90,min(90,atan(sinh(-p.y / radius)) * 180 / .pi)), TrailGeography.wrap(p.x / radius * 180 / .pi))
    }
}
