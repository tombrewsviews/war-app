import SwiftUI

struct Tile: View {
    let title: String
    let icon: String
    let color: Color
    var secondaryIcon: String? = nil
    var secondaryColor: Color? = nil

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 56, height: 56)
                    .glassEffect(.regular.tint(color.opacity(0.45)), in: .circle)

                if let secondaryIcon, let secondaryColor {
                    Image(systemName: secondaryIcon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(secondaryColor, in: .circle)
                        .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 1.5))
                        .offset(x: 6, y: 2)
                }
            }

            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, minHeight: 108, maxHeight: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 10)
        .glassEffect(.regular.tint(color.opacity(0.13)).interactive(), in: .rect(cornerRadius: 26, style: .continuous))
    }
}
