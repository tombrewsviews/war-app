import SwiftUI

/// Reached from the "?" button in the home status bar — general app info, contact details and a
/// help/FAQ placeholder. FAQ content itself will be filled in later; the section ships now so the
/// entry point already exists.
struct AppInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var appEnvironment

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    commandCenterSection

                    infoSection(
                        icon: "info.circle.fill",
                        tint: .blue,
                        title: "O aplikacji",
                        content: "WarApp pomaga przygotować się i działać w sytuacjach kryzysowych: alarmuje o zagrożeniach, umożliwia komunikację Mesh bez internetu, prowadzi krok po kroku przez pierwszą pomoc i wskazuje najbliższe schrony."
                    )

                    infoSection(
                        icon: "person.2.fill",
                        tint: .indigo,
                        title: "Twórcy",
                        content: "Zespół WarApp. Pełne informacje o autorach zostaną uzupełnione."
                    )

                    infoSection(
                        icon: "envelope.fill",
                        tint: .teal,
                        title: "Dane teleadresowe",
                        content: "Dane kontaktowe i adresowe zostaną uzupełnione."
                    )

                    websiteButton

                    infoSection(
                        icon: "questionmark.circle.fill",
                        tint: .purple,
                        title: "Pomoc",
                        content: "Każda sekcja aplikacji zawiera opis i instrukcje krok po kroku. W razie problemu skorzystaj z danych kontaktowych powyżej."
                    )

                    faqSection
                }
                .padding()
            }
            .navigationTitle("Informacje")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.blue)
                .glassBadge(tint: .blue, size: 52, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("WarApp")
                .font(.title.weight(.bold))
            Text("Centrum Kryzysowe w Twojej kieszeni.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var commandCenterSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(commandCenterColor)
                .contentTransition(.symbolEffect(.replace))
                .glassBadge(tint: commandCenterColor, size: 40, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .animation(.default, value: commandCenterColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("Centrum Dowodzenia")
                    .font(.subheadline.weight(.semibold))
                Text(commandCenterStatusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
            }

            Spacer()

            Button {
                Task { await appEnvironment.commandCenterStatus.check() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.tilePress)
        }
        .padding(12)
        .glassCard(tint: commandCenterColor, cornerRadius: 14)
        .animation(.snappy, value: appEnvironment.commandCenterStatus.state)
    }

    private var commandCenterColor: Color {
        switch appEnvironment.commandCenterStatus.state {
        case .unknown: return .secondary
        case .reachable: return .green
        case .unreachable: return .red
        }
    }

    private var commandCenterStatusText: String {
        let status = appEnvironment.commandCenterStatus
        let time = status.lastCheckedAt.map { $0.formatted(date: .omitted, time: .shortened) }
        switch status.state {
        case .unknown:
            return "Sprawdzanie połączenia…"
        case .reachable:
            return time.map { "Połączenie z Centrum działa · sprawdzono \($0)" } ?? "Połączenie z Centrum działa."
        case .unreachable:
            return time.map { "Brak połączenia z Centrum · ostatnia próba \($0)" } ?? "Brak połączenia z Centrum."
        }
    }

    private var websiteButton: some View {
        Button {
            if let url = URL(string: "https://aczykoty.github.io/warapp-backend/") {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .foregroundStyle(.teal)
                Text("Strona internetowa")
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.semibold))
            .padding(12)
        }
        .buttonStyle(.tilePress)
        .glassCard(tint: .teal, cornerRadius: 14)
    }

    private func infoSection(icon: String, tint: Color, title: String, content: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .glassBadge(tint: tint, size: 40, in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(content)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .glassCard(tint: tint, cornerRadius: 14)
    }

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.bubble.fill")
                    .foregroundStyle(.orange)
                Text("FAQ")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Wkrótce")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            Text("Najczęściej zadawane pytania pojawią się tutaj wkrótce.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .glassCard(tint: .orange, cornerRadius: 14)
    }
}

#Preview {
    AppInfoView()
        .environment(AppEnvironment())
}
