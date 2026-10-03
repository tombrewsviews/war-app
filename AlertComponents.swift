import SwiftUI

struct AlertCard: View {
    let item: AlertItem
    var isExpired: Bool = false

    private var tint: Color {
        isExpired ? .gray : item.severity.color
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: isExpired ? "archivebox.fill" : item.severity.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .glassBadge(tint: tint, size: 40, in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isExpired ? .secondary : .primary)

                Text(item.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    if let location = item.location {
                        Label(location, systemImage: "mappin.and.ellipse")
                    }
                    Text(item.createdAt, style: .relative)
                    Text("temu")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .glassCard(tint: tint, cornerRadius: 14)
    }
}

struct PendingAlertCard: View {
    let item: AlertItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "hourglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.orange)
                .glassBadge(tint: .orange, size: 40, in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.severity.label.uppercased())
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(item.severity.color)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())

                    Text("Oczekuje na weryfikację sztabu")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }

                Text(item.title)
                    .font(.subheadline.weight(.semibold))

                Text(item.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Widoczne tylko dla Ciebie, dopóki sztab nie potwierdzi zgłoszenia.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .glassCard(tint: .orange, cornerRadius: 14)
    }
}

struct EmptyAlertsPlaceholder: View {
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
