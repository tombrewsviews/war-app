import SwiftUI

struct NewsTicker: View {
    let items: [String]

    @State private var contentWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    private var joinedText: String {
        items.joined(separator: "     •     ") + "     •     "
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "dot.radiowaves.up.forward")
                .foregroundStyle(.orange)

            GeometryReader { geo in
                Text(joinedText)
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
                    .fixedSize()
                    .background(WidthReader())
                    .offset(x: offset)
                    .onPreferenceChange(TickerWidthKey.self) { width in
                        contentWidth = width
                        startAnimating(visibleWidth: geo.size.width)
                    }
            }
            .frame(height: 20)
            .clipped()
        }
        .padding(.horizontal)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(.orange.opacity(0.28)), in: .rect(cornerRadius: 0))
    }

    private func startAnimating(visibleWidth: CGFloat) {
        guard contentWidth > 0 else { return }
        offset = visibleWidth
        withAnimation(.linear(duration: Double(contentWidth) / 40).repeatForever(autoreverses: false)) {
            offset = -contentWidth
        }
    }
}

private struct TickerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct WidthReader: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: TickerWidthKey.self, value: proxy.size.width)
        }
    }
}

#Preview {
    NewsTicker(items: [
        "Alarm przeciwlotniczy odwołany dla dzielnicy Centrum",
        "Dostawa wody pitnej w punkcie przy ul. Długiej 12 od 14:00",
        "Schron przy Szkole nr 4 otwarty całą dobę"
    ])
}
