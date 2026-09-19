import Testing
import Foundation
@testable import TrailCore
import TrailEffects

private struct GeoPoseCase: Sendable, CustomStringConvertible {
    let lat: Double, lon: Double, north: Bool, progress: Double, reverse: Bool
    var description: String { "\(lat)/\(lon)/north=\(north)/p=\(progress)/reverse=\(reverse)" }
    static var all: [Self] {
        var result: [Self] = []
        for lat in [-60.0,0,60] { for lon in [-73.0,179] { for north in [false,true] {
            for p in [0.0,0.01,0.25,0.5,0.99,1] { for reverse in [false,true] {
                result.append(Self(lat: lat,lon: lon,north: north,progress: p,reverse: reverse))
            } }
        } } }
        return result
    }
}
@Test(arguments: GeoPoseCase.all)
private func nativeHeadHasAnalyticGeographicPositionAndBearing(_ c: GeoPoseCase) throws {
    let a = try TrailCoordinate(latitude: c.lat,longitude: c.lon)
    let b = try TrailCoordinate(latitude: c.north ? c.lat+2 : c.lat,longitude: c.north ? c.lon : c.lon+2 > 180 ? c.lon-358 : c.lon+2)
    let geometry = TrailMapGeometry(try .direct(id: "test",from: a,to: b))
    let pose = try #require(geometry.pose(at: c.progress,direction: c.reverse ? .reverse : .forward))
    func y(_ degrees: Double) -> Double { log(tan(.pi/4+degrees * .pi/360)) }
    let expectedLat = c.north ? atan(sinh(y(c.lat)+(y(c.lat+2)-y(c.lat))*c.progress))*180 / .pi : c.lat
    let expectedLon = c.north ? c.lon : (c.lon+2*c.progress+180).truncatingRemainder(dividingBy: 360)-180
    #expect(abs(expectedLat-pose.coordinate.latitude)<1e-8)
    #expect(abs(TrailGeography.delta(expectedLon,pose.coordinate.longitude))<1e-8)
    let expectedBearing = (c.north ? 0.0 : 90.0)+(c.reverse ? 180.0 : 0.0)
    #expect(abs(expectedBearing-pose.bearing)<1e-6)
    let strokes = geometry.strokes(layer: TrailLayer(style: TrailStyles.solid()),state: .reveal(to: c.progress),unitsPerPoint: 1)
    if c.progress > 0 {
        let end = try #require(strokes.last?.coordinates.last)
        #expect(abs(end.latitude-pose.coordinate.latitude)<1e-8)
        #expect(abs(TrailGeography.delta(end.longitude,pose.coordinate.longitude))<1e-8)
    } else { #expect(strokes.isEmpty) }
    #expect(strokes.allSatisfy { s in zip(s.coordinates,s.coordinates.dropFirst()).allSatisfy { abs($1.longitude-$0.longitude)<=180 } })
}

private struct MorphCase: Sendable {
    let lat: Double, lon: Double, p: Double
    static var all: [Self] { [-60.0,0,60].flatMap { lat in [-73.0,179].flatMap { lon in
        [0.0,0.01,0.25,0.5,0.75,0.99,1].map { Self(lat: lat,lon: lon,p: $0) }
    } } }
}
@Test(arguments: MorphCase.all)
private func morphPreservesEndpointsAndExactFinalRoadIncludingWorldWrap(_ c: MorphCase) throws {
    let a = try TrailCoordinate(latitude: c.lat,longitude: c.lon)
    let endLon = TrailGeography.wrap(c.lon+2)
    let b = try TrailCoordinate(latitude: c.lat+1,longitude: endLon)
    let road = try TrailRoute(id: "road",coordinates: [a,TrailCoordinate(latitude: c.lat+0.3,longitude: c.lon),TrailCoordinate(latitude: c.lat+0.3,longitude: endLon),b],revision: 7)
    let arc = try TrailRoute.arc(id: "loading",from: a,to: b)
    let morph = try TrailRouteMorph(from: arc,to: road)
    let frame = morph.route(at: c.p)
    #expect(abs(frame.coordinates.first!.latitude-a.latitude)<1e-8)
    #expect(abs(frame.coordinates.last!.latitude-b.latitude)<1e-8)
    #expect(abs(TrailGeography.delta(a.longitude,frame.coordinates.first!.longitude))<1e-8)
    #expect(abs(TrailGeography.delta(b.longitude,frame.coordinates.last!.longitude))<1e-8)
    #expect(frame.segments.allSatisfy { s in zip(s,s.dropFirst()).allSatisfy { abs($1.longitude-$0.longitude)<=180 } })
    if c.p == 0 { #expect(frame.coordinates == arc.coordinates) }
    if c.p == 1 { #expect(frame.coordinates == road.coordinates); #expect(frame.revision == 7) }
    var state = try TrailRouteTransition(from: a,to: b)
    #expect(try { try state.resolve(state.request,route: road) }())
    state.advance(by: state.durationSeconds*c.p)
    #expect(state.phase == (c.p == 1 ? .ready : .morphing))
    if c.p == 1 { #expect(state.route.coordinates == road.coordinates) }
}

@Test func requestsRejectStaleDuplicateAndCrossInstanceResponses() throws {
    let a = try TrailCoordinate(latitude: 40,longitude: -73), b = try TrailCoordinate(latitude: 40.001,longitude: -73.002)
    let road = try TrailRoute.direct(id: "road",from: a,to: b)
    var state = try TrailRouteTransition(from: a,to: b)
    let old = state.request, next = try state.begin(from: a,to: b)
    #expect(try { try !state.resolve(old,route: road) }()); #expect({ !state.fail(old) }()); #expect({ !state.cancel(old) }())
    let foreign = try TrailRouteTransition(from: a,to: b).request
    #expect(try { try !state.resolve(foreign,route: road) }()); #expect(state.phase == .loading)
    #expect(try { try state.resolve(next,route: road) }()); #expect(try { try !state.resolve(next,route: road) }())
    #expect({ !state.fail(next) }()); #expect({ !state.cancel(next) }())
    state.advance(by: 100); #expect(state.phase == .ready); #expect(state.route.coordinates == road.coordinates)
}
@Test func failedCancelledRetriedAndReducedRequestsHaveExplicitStates() throws {
    let a = try TrailCoordinate(latitude: 40,longitude: -73), b = try TrailCoordinate(latitude: 40.001,longitude: -73.002)
    let road = try TrailRoute.direct(id: "road",from: a,to: b)
    var state = try TrailRouteTransition(from: a,to: b)
    #expect({ state.fail(state.request) }()); #expect(try { try !state.resolve(state.request,route: road) }())
    let retry = try state.begin(from: a,to: b); #expect({ state.cancel(retry) }()); #expect({ !state.fail(retry) }())
    let next = try state.begin(from: a,to: b)
    #expect(try { try state.resolve(next,route: road,reducedMotion: true) }()); #expect(state.phase == .ready)
    try state.begin(from: a,to: b); try state.resolve(state.request,route: road); state.advance(by: 0.1)
    state.advance(by: 0,reducedMotion: true); #expect(state.route.coordinates == road.coordinates)
}
@Test func newRequestInterruptsMorphAndInvalidResponseIsRecoverable() throws {
    let a = try TrailCoordinate(latitude: 40,longitude: -73), b = try TrailCoordinate(latitude: 40.001,longitude: -73.002)
    let road = try TrailRoute.direct(id: "road",from: a,to: b)
    var state = try TrailRouteTransition(from: a,to: b)
    let wrong = try TrailRoute.direct(id: "wrong",from: TrailCoordinate(latitude: 0,longitude: 0),to: TrailCoordinate(latitude: 1,longitude: 1))
    #expect(throws: TrailError.self) { try state.resolve(state.request,route: wrong) }
    #expect(state.phase == .loading)
    try state.resolve(state.request,route: road); state.advance(by: 0.2)
    try state.begin(from: b,to: a); let arc = state.route
    state.advance(by: 30); #expect(state.phase == .loading); #expect(state.route.coordinates == arc.coordinates)
}
@Test(arguments: TrailStylePreset.allCases, TrailMotionPreset.allCases)
func allNativeMapStyleAndMotionPairsRemainBounded(style: TrailStylePreset, motion: TrailMotionPreset) throws {
    let points = try [(40.0,-73.0),(40.002,-73.0),(40.002,-72.998),(40.004,-72.998)].map { try TrailCoordinate(latitude: $0.0,longitude: $0.1) }
    let geometry = TrailMapGeometry(try TrailRoute(id: "road",coordinates: points))
    let effect = motion.effect(style: style.style())
    for p in [0.0,0.2,0.8,1] {
        let state = effect.sample(layer: 0,elapsed: p*effect.durationSeconds)
        let strokes = geometry.strokes(layer: effect.layers[0],state: state,unitsPerPoint: 2)
        #expect(strokes.count <= 8192)
        #expect(strokes.allSatisfy { $0.width.isFinite && $0.width>0 && $0.coordinates.count>=2 && $0.dashPhase.isFinite })
    }
}
@Test func fullNativeLayersRetainAllHundredThousandRoadVertices() throws {
    let points = try (0..<100_000).map { try TrailCoordinate(latitude: 40+Double($0)*1e-7,longitude: -73+Double($0%2)*1e-5) }
    let geometry = TrailMapGeometry(try TrailRoute(id: "road",coordinates: points))
    let strokes = geometry.strokes(layer: TrailLayer(style: TrailStyles.cased()),state: .full,unitsPerPoint: 1)
    #expect(strokes.count==2); #expect(strokes[0].coordinates==points); #expect(strokes[1].coordinates==points)
}
