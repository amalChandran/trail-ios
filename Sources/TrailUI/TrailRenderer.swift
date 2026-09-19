import CoreGraphics
import Foundation
import TrailCore

/// Core Graphics executor. Each draw saves/restores all graphics state.
public enum TrailRenderer {
    public static func draw(path: TrailPath, effect: TrailEffect, in context: CGContext, frame: (Int) -> TrailVisualState) {
        TrailPreparedRenderer(path: path).draw(effect: effect,in: context,frame: frame)
    }
}

/// Retain per surface: fixed stroke ranges reuse prepared Core Graphics paths. Not shared across threads.
public final class TrailPreparedRenderer {
    private let path: TrailPath
    private struct Range: Hashable { let start: Double, end: Double }
    private struct Section { let path: CGPath, offset: Double }
    private var ranges: [Range:[Section]] = [:]
    public init(path: TrailPath) { self.path = path }
    private func sections(_ start: Double, _ end: Double) -> [Section] {
        let key = Range(start: start,end: end)
        if let prepared = ranges[key] { return prepared }
        let result = path.slices(from: start,to: end).compactMap { slice -> Section? in
            guard let first = slice.points.first else { return nil }
            let cg = CGMutablePath(); cg.move(to: CGPoint(x: first.x,y: first.y))
            for point in slice.points.dropFirst() { cg.addLine(to: CGPoint(x: point.x,y: point.y)) }
            return Section(path: cg,offset: slice.distanceFromStart)
        }
        // Cache only fixed ranges prepared by a style, not every moving reveal boundary.
        return result
    }
    public func draw(effect: TrailEffect, in context: CGContext, frame: (Int) -> TrailVisualState) {
        guard path.length > 0 else { return }
        context.saveGState(); defer { context.restoreGState() }
        context.setLineJoin(.round)
        for (index, layer) in effect.layers.enumerated() {
            let state = frame(index)
            guard state.opacity > 0 && state.widthScale > 0 else { continue }
            for command in layer.commands {
                switch command {
                case .stroke(let stroke):
                    context.setLineWidth(stroke.width * state.widthScale)
                    context.setLineCap(stroke.roundCap ? .round : .butt)
                    let cycle = stroke.dash.reduce(0, +)
                    for window in state.windows {
                        let start = max(stroke.start, window.start), end = min(stroke.end, window.end)
                        guard start < end else { continue }
                        context.setStrokeColor(stroke.color.cgColor)
                        context.setAlpha(state.opacity * window.opacity)
                        let key = Range(start: start,end: end)
                        let prepared = sections(start,end)
                        if start == stroke.start && end == stroke.end && ranges[key] == nil {
                            if ranges.count >= 512 { ranges.removeAll(keepingCapacity: true) }
                            ranges[key] = prepared
                        }
                        for section in prepared {
                            context.setLineDash(phase: cycle == 0 ? 0 : (section.offset - state.dashPhase * cycle).truncatingRemainder(dividingBy: cycle), lengths: stroke.dash.map { CGFloat($0) })
                            context.addPath(section.path); context.strokePath()
                        }
                    }
                case .chevrons(let stamp):
                    let count = min(2048, Int(min(2048, floor(path.length / stamp.spacing))))
                    context.setLineDash(phase: 0, lengths: []); context.setLineCap(.round)
                    context.setLineWidth(stamp.size * 0.25 * state.widthScale); context.setStrokeColor(stamp.color.cgColor)
                    for i in 0..<count {
                        let fraction = ((Double(i) + 0.5) * stamp.spacing / path.length + state.dashPhase * stamp.spacing / path.length).truncatingRemainder(dividingBy: 1)
                        guard let window = state.windows.first(where: { fraction >= $0.start && fraction <= $0.end }), let point = path.point(at: fraction) else { continue }
                        context.saveGState(); context.setAlpha(state.opacity * window.opacity)
                        context.translateBy(x: point.x, y: point.y); context.rotate(by: path.tangent(at: fraction))
                        let size = stamp.size * state.widthScale
                        context.beginPath(); context.move(to: CGPoint(x: -size / 2, y: -size / 2))
                        context.addLine(to: CGPoint(x: size / 2, y: 0)); context.addLine(to: CGPoint(x: -size / 2, y: size / 2))
                        context.strokePath(); context.restoreGState()
                    }
                }
            }
        }
    }
}

private extension TrailColor {
    // ARGB values have sRGB components on both platforms; do not depend on the device profile.
    static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    var cgColor: CGColor { CGColor(colorSpace: Self.colorSpace, components: [Double((argb >> 16) & 255) / 255, Double((argb >> 8) & 255) / 255, Double(argb & 255) / 255, Double((argb >> 24) & 255) / 255])! }
}
