import SwiftUI

/// Panel outline used for both styles:
/// - notch: concave `earRadius` at the top blends into the menu bar, square top corners;
/// - island: convex `topCornerRadius`, no ears (a capsule when collapsed).
/// Only one of `earRadius` / `topCornerRadius` is expected to be non-zero.
///
/// The ears sit inside the rect, so the body is `rect.width - 2 * earRadius` wide.
struct NotchShape: Shape {
    var earRadius: CGFloat
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(earRadius, AnimatablePair(topCornerRadius, bottomCornerRadius)) }
        set {
            earRadius = newValue.first
            topCornerRadius = newValue.second.first
            bottomCornerRadius = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let ear = min(earRadius, rect.width / 4, rect.height / 2)
        let bodyWidth = rect.width - 2 * ear
        let top = min(topCornerRadius, bodyWidth / 2, rect.height / 2)
        let bottom = min(bottomCornerRadius, bodyWidth / 2, rect.height - ear - top)

        let left = rect.minX + ear
        let right = rect.maxX - ear

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + top, y: rect.minY))
        // Top-left: concave ear (top == 0) or convex corner (ear == 0).
        path.addQuadCurve(
            to: CGPoint(x: left, y: rect.minY + ear + top),
            control: CGPoint(x: left, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: left, y: rect.maxY - bottom))
        path.addQuadCurve(
            to: CGPoint(x: left + bottom, y: rect.maxY),
            control: CGPoint(x: left, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: right - bottom, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: right, y: rect.maxY - bottom),
            control: CGPoint(x: right, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: right, y: rect.minY + ear + top))
        // Top-right, mirrored.
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - top, y: rect.minY),
            control: CGPoint(x: right, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}
