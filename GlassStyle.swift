import SwiftUI

extension View {
    /// A small icon roundel rendered with Liquid Glass, tinted to match a section's accent color.
    /// Mirrors the shape+size footprint of the flat `.background(tint.opacity(...)).clipShape(...)`
    /// badges used throughout the app, so it's a drop-in replacement.
    func glassBadge(tint: Color, size: CGFloat, in shape: some Shape = RoundedRectangle(cornerRadius: 12, style: .continuous)) -> some View {
        self
            .frame(width: size, height: size)
            .glassEffect(.regular.tint(tint.opacity(0.5)), in: shape)
    }

    /// A full glass panel background for cards/boxes, replacing flat tinted rounded-rectangle fills.
    /// Pass `tint: nil` for a neutral (untinted) glass panel. Set `interactive: true` for cards that
    /// are themselves a button/NavigationLink, so tapping also gives the native glass shimmer
    /// response alongside `TilePressStyle`'s scale.
    func glassCard(tint: Color? = nil, cornerRadius: CGFloat = 16, interactive: Bool = false) -> some View {
        var glass: Glass = tint.map { Glass.regular.tint($0.opacity(0.16)) } ?? Glass.regular
        if interactive { glass = glass.interactive() }
        return self.glassEffect(glass, in: .rect(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// A scale-down-on-press feel with a jelly-like overshoot on release, for tile/menu-row style
/// `NavigationLink`s/`Button`s. Deliberately a `ButtonStyle` (reacting to `isPressed`) rather than
/// a custom gesture — attaching a competing gesture recognizer (e.g. `DragGesture`) to a
/// Button/NavigationLink interferes with its own tap recognition and can require a hold before it
/// registers, or stop opening the destination for quick taps entirely. The small delay before the
/// press-down visual appears inside a `ScrollView` is standard iOS touch-disambiguation behavior
/// (same as system apps) and isn't safe to fight around.
struct TilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(
                configuration.isPressed
                    ? .easeOut(duration: 0.12)
                    : .spring(response: 0.32, dampingFraction: 0.45),
                value: configuration.isPressed
            )
    }
}

extension ButtonStyle where Self == TilePressStyle {
    static var tilePress: TilePressStyle { TilePressStyle() }
}
