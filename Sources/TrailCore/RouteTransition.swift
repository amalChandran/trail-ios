import Foundation

/// Prepared geometry correspondence. Every target corner survives the morph.
public struct TrailRouteMorph: Sendable {
    public let from: TrailRoute, to: TrailRoute
    private let start: [TrailPoint], end: [TrailPoint]
    public init(from: TrailRoute, to: TrailRoute, samples: Int = 128) throws {
        guard from.coordinates.count >= 2, to.coordinates.count >= 2, (2...2048).contains(samples) else { throw TrailError.invalidRoute("A morph needs two routes and 2...2048 samples") }
        self.from = from; self.to = to
        func unwrapped(_ coordinates: [TrailCoordinate]) -> TrailPath {
            var previous = coordinates[0].longitude, longitude = previous
            return TrailPath(coordinates.enumerated().map { index, c in
                if index > 0 { longitude += TrailGeography.delta(previous,c.longitude); previous = c.longitude }
                return TrailPoint(longitude / 360 * TrailMapGeometry.worldMeters, TrailMapGeometry.point(c).y)
            })
        }
        let a = unwrapped(from.coordinates), rawB = unwrapped(to.coordinates)
        let shift = round((a.points[0].x - rawB.points[0].x) / TrailMapGeometry.worldMeters) * TrailMapGeometry.worldMeters
        let b = TrailPath(rawB.points.map { TrailPoint($0.x + shift,$0.y) })
        guard a.length > 0, b.length > 0 else { throw TrailError.invalidRoute("A morph needs nonzero route lengths") }
        var fractions: Set<Double> = [0,1], distance = 0.0
        for i in 1..<b.points.count {
            distance += hypot(b.points[i].x-b.points[i-1].x,b.points[i].y-b.points[i-1].y)
            fractions.insert(max(0,min(1,distance/b.length)))
        }
        if fractions.count + samples <= 100_000 { for i in 1..<samples { fractions.insert(Double(i)/Double(samples)) } }
        let sorted = fractions.sorted()
        start = sorted.map { a.point(at: $0)! }; end = sorted.map { b.point(at: $0)! }
    }
    /// Exact endpoints return the original geometry; progress is already eased by the caller.
    public func route(at progress: Double) -> TrailRoute {
        fractionCheck(progress)
        if progress == 0 { return from }; if progress == 1 { return to }
        let points = start.indices.map { i in TrailMapGeometry.coordinate(TrailPoint(
            start[i].x + (end[i].x-start[i].x)*progress, start[i].y + (end[i].y-start[i].y)*progress)) }
        return try! TrailRoute(id: to.id,coordinates: points,revision: to.revision)
    }
}
public enum TrailRoutePhase: Sendable { case loading, morphing, ready, failed, cancelled }
public struct TrailRouteRequest: Sendable, Equatable { private let identity = UUID(); init() {} }

/// Deterministic request state. Tokens reject late, repeated and cross-instance responses.
public struct TrailRouteTransition: Sendable {
    public private(set) var request = TrailRouteRequest()
    public private(set) var phase = TrailRoutePhase.loading
    public private(set) var route: TrailRoute
    public let durationSeconds: Double
    private var origin: TrailCoordinate, destination: TrailCoordinate
    private var morph: TrailRouteMorph?
    private var elapsed = 0.0
    public init(from: TrailCoordinate, to: TrailCoordinate, durationSeconds: Double = 0.65) throws {
        guard durationSeconds.isFinite, durationSeconds > 0, durationSeconds <= 10 else { throw TrailError.invalidRoute("Morph duration must be in (0,10] seconds") }
        self.durationSeconds = durationSeconds; origin = from; destination = to
        route = try .arc(id: "trail/loading",from: from,to: to)
    }
    @discardableResult public mutating func begin(from: TrailCoordinate, to: TrailCoordinate) throws -> TrailRouteRequest {
        let arc = try TrailRoute.arc(id: "trail/loading",from: from,to: to)
        request = TrailRouteRequest(); origin = from; destination = to; route = arc
        phase = .loading; morph = nil; elapsed = 0
        return request
    }
    @discardableResult public mutating func resolve(_ request: TrailRouteRequest, route: TrailRoute, reducedMotion: Bool = false) throws -> Bool {
        guard request == self.request, phase == .loading else { return false }
        guard route.coordinates.count >= 2, route.distanceMeters > 0 else { throw TrailError.invalidRoute("Resolved directions need at least two distinct coordinates") }
        guard TrailGeography.distance(origin,route.coordinates.first!) <= 150,
              TrailGeography.distance(destination,route.coordinates.last!) <= 150 else { throw TrailError.invalidRoute("Resolved route endpoints must match within 150 meters, including road snapping") }
        if reducedMotion || self.route.distanceMeters == 0 { self.route = route; phase = .ready }
        else { morph = try TrailRouteMorph(from: self.route,to: route); elapsed = 0; phase = .morphing }
        return true
    }
    @discardableResult public mutating func fail(_ request: TrailRouteRequest) -> Bool { finish(request,phase: .failed) }
    @discardableResult public mutating func cancel(_ request: TrailRouteRequest) -> Bool { finish(request,phase: .cancelled) }
    private mutating func finish(_ request: TrailRouteRequest, phase: TrailRoutePhase) -> Bool {
        guard request == self.request, self.phase == .loading else { return false }
        self.phase = phase; return true
    }
    public mutating func advance(by seconds: Double, reducedMotion: Bool = false) {
        precondition(seconds.isFinite && seconds >= 0)
        guard phase == .morphing else { return }
        elapsed = min(durationSeconds,elapsed+seconds)
        let p = reducedMotion ? 1 : elapsed/durationSeconds
        route = morph!.route(at: p == 1 ? 1 : p*p*p*(10+p*(-15+6*p)))
        if p == 1 { morph = nil; phase = .ready }
    }
}
