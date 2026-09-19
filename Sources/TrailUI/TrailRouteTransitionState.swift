import SwiftUI
import TrailCore

/// Capture request before awaiting directions. Late responses cannot replace a newer request.
@MainActor @Observable public final class TrailRouteTransitionState {
    private var model: TrailRouteTransition
    public var request: TrailRouteRequest { model.request }
    public var phase: TrailRoutePhase { model.phase }
    public var route: TrailRoute { model.route }
    public init(from: TrailCoordinate, to: TrailCoordinate, durationSeconds: Double = 0.65) throws {
        model = try TrailRouteTransition(from: from,to: to,durationSeconds: durationSeconds)
    }
    @discardableResult public func begin(from: TrailCoordinate, to: TrailCoordinate) throws -> TrailRouteRequest { try model.begin(from: from,to: to) }
    @discardableResult public func resolve(_ request: TrailRouteRequest, route: TrailRoute) throws -> Bool { try model.resolve(request,route: route) }
    @discardableResult public func fail(_ request: TrailRouteRequest) -> Bool { model.fail(request) }
    @discardableResult public func cancel(_ request: TrailRouteRequest) -> Bool { model.cancel(request) }
    fileprivate func advance(_ seconds: Double, reduced: Bool) { model.advance(by: seconds,reducedMotion: reduced) }
}
public extension View {
    /// Drives only the brief geometry morph, and freezes while backgrounded or inactive.
    func trailRouteTransition(_ state: TrailRouteTransitionState, active: Bool = true, reducedMotion: Bool = false) -> some View {
        modifier(RouteTransitionModifier(state: state,active: active,forceReduced: reducedMotion))
    }
}
private struct RouteTransitionModifier: ViewModifier {
    let state: TrailRouteTransitionState
    let active: Bool, forceReduced: Bool
    @Environment(\.scenePhase) private var scene
    @Environment(\.accessibilityReduceMotion) private var systemReduced
    private var running: Bool { active && scene == .active && state.phase == .morphing }
    func body(content: Content) -> some View {
        content.task(id: "\(running)/\(forceReduced || systemReduced)") {
            guard running else { return }
            if forceReduced || systemReduced { state.advance(0,reduced: true); return }
            let clock = ContinuousClock(); var previous = clock.now
            while !Task.isCancelled && state.phase == .morphing {
                do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
                let now = clock.now, delta = previous.duration(to: now); previous = now
                state.advance(Double(delta.components.seconds) + Double(delta.components.attoseconds)/1e18,reduced: false)
            }
        }
    }
}
