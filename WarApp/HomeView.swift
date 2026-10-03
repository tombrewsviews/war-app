import SwiftUI

struct HomeView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @State private var showAlertsPopover = false
    @State private var showMeshPopover = false
    @State private var showGPSPopover = false
    @State private var showSyncPopover = false
    @State private var showInfo = false
    @State private var pendingDestination: HomeDestination?
    @Namespace private var tileNamespace

    var body: some View {
        VStack(spacing: 0) {
            statusHeader

            GeometryReader { geometry in
                ScrollView(showsIndicators: false) {
                    GlassEffectContainer(spacing: 12) {
                    VStack(spacing: 12) {
                        row {
                            zoomLink("alerts", destination: AlertView()) {
                                Tile(title: "Alerty", icon: "exclamationmark.triangle.fill", color: .red)
                            }
                            zoomLink("firstaid", destination: FirstAidView()) {
                                Tile(title: "Pierwsza pomoc", icon: "cross.case.fill", color: .green)
                            }
                        }

                        row {
                            zoomLink("light", destination: LightSignalView()) {
                                Tile(title: "Sygnały świetlne", icon: "flashlight.on.fill", color: .yellow)
                            }
                            zoomLink("mesh", destination: CommunicationView()) {
                                Tile(title: "Komunikacja Mesh", icon: "antenna.radiowaves.left.and.right", color: .blue)
                            }
                        }

                        row {
                            zoomLink("shelters", destination: SheltersView()) {
                                Tile(
                                    title: "Schrony i punkty pomocy",
                                    icon: "building.2.fill",
                                    color: .brown,
                                    secondaryIcon: "cross.fill",
                                    secondaryColor: .red
                                )
                            }
                            zoomLink("map", destination: OfflineMapView()) {
                                Tile(
                                    title: "Mapa i kompas",
                                    icon: "map.fill",
                                    color: .teal,
                                    secondaryIcon: "location.north.line.fill",
                                    secondaryColor: .purple
                                )
                            }
                        }

                        row {
                            zoomLink("news", destination: NewsNowView()) {
                                Tile(title: "News NOW", icon: "newspaper.fill", color: .indigo)
                            }
                            zoomLink("prep", destination: SurvivalPrepView()) {
                                Tile(title: "Przetrwanie", icon: "backpack.fill", color: .mint)
                            }
                        }
                    }
                    .padding()
                    .frame(minHeight: geometry.size.height)
                    }
                }
            }

            NewsTicker(items: [
                "Alarm przeciwlotniczy odwołany dla dzielnicy Centrum",
                "Dostawa wody pitnej w punkcie przy ul. Długiej 12 od 14:00",
                "Schron przy Szkole nr 4 otwarty całą dobę"
            ])
        }
        .background(homeBackground)
        .navigationBarHidden(true)
        .navigationDestination(item: $pendingDestination) { destination in
            switch destination {
            case .alerts: AlertView()
            case .mesh: CommunicationView()
            case .map: OfflineMapView()
            }
        }
    }

    private func row(@ViewBuilder _ content: () -> some View) -> some View {
        HStack(spacing: 12) {
            content()
        }
        .frame(maxHeight: .infinity)
    }

    /// A tile `NavigationLink` that zooms into its destination from the tile's own position and
    /// size — tapping a tile expands it into the full screen while the rest of the grid fades,
    /// instead of a flat push.
    private func zoomLink(_ id: String, destination: some View, @ViewBuilder label: () -> some View) -> some View {
        NavigationLink {
            destination
                .navigationTransition(.zoom(sourceID: id, in: tileNamespace))
        } label: {
            label()
                .matchedTransitionSource(id: id, in: tileNamespace)
        }
        .buttonStyle(.tilePress)
    }

    private var statusHeader: some View {
        HStack(spacing: 8) {
                if criticalAlertCount > 0 {
                    Button {
                        showAlertsPopover = true
                    } label: {
                        StatusIcon(
                            icon: "exclamationmark.triangle.fill",
                            color: .red,
                            badge: criticalAlertCount
                        )
                    }
                    .transition(.scale.combined(with: .opacity))
                    .popover(isPresented: $showAlertsPopover) {
                        StatusPopover(
                            icon: "exclamationmark.triangle.fill",
                            color: .red,
                            title: "Alerty krytyczne",
                            message: alertsPopoverMessage,
                            actionTitle: "Zobacz alerty"
                        ) {
                            showAlertsPopover = false
                            pendingDestination = .alerts
                        }
                        .presentationCompactAdaptation(.popover)
                    }
                }

                Button {
                    showMeshPopover = true
                } label: {
                    StatusPill(
                        title: "MESH",
                        value: meshStatusLabel,
                        icon: "antenna.radiowaves.left.and.right",
                        color: meshColor
                    )
                }
                .popover(isPresented: $showMeshPopover) {
                    StatusPopover(
                        icon: "antenna.radiowaves.left.and.right",
                        color: meshColor,
                        title: "Sieć MESH",
                        message: meshPopoverMessage,
                        actionTitle: "Otwórz Komunikację Mesh"
                    ) {
                        showMeshPopover = false
                        pendingDestination = .mesh
                    }
                    .presentationCompactAdaptation(.popover)
                }

                Button {
                    pendingDestination = .mesh
                } label: {
                    StatusIcon(
                        icon: "message.fill",
                        color: chatMessageCount > 0 ? .blue : .secondary,
                        badge: chatMessageCount
                    )
                }
                .accessibilityLabel("Wiadomości czatu")
                .accessibilityValue("\(unreadGeneralCount) na czacie ogólnym, \(unreadDirectCount) prywatnych")

                Button {
                    showGPSPopover = true
                } label: {
                    StatusPill(
                        title: "GPS",
                        value: appEnvironment.locationStatus.hasRecentFix ? "OK" : "BRAK",
                        icon: appEnvironment.locationStatus.hasRecentFix ? "location.fill" : "location.slash.fill",
                        color: appEnvironment.locationStatus.hasRecentFix ? .green : .red
                    )
                }
                .popover(isPresented: $showGPSPopover) {
                    StatusPopover(
                        icon: "location.fill",
                        color: appEnvironment.locationStatus.hasRecentFix ? .green : .red,
                        title: "Lokalizacja GPS",
                        message: gpsPopoverMessage,
                        actionTitle: "Otwórz mapę"
                    ) {
                        showGPSPopover = false
                        pendingDestination = .map
                    }
                    .presentationCompactAdaptation(.popover)
                }

                Button {
                    showSyncPopover = true
                } label: {
                    StatusIcon(icon: syncIcon, color: syncColor)
                        .contentTransition(.symbolEffect(.replace))
                }
                .popover(isPresented: $showSyncPopover) {
                    StatusPopover(
                        icon: syncIcon,
                        color: syncColor,
                        title: "Synchronizacja z sztabem",
                        message: syncPopoverMessage,
                        actionTitle: "Otwórz Komunikację Mesh"
                    ) {
                        showSyncPopover = false
                        pendingDestination = .mesh
                    }
                    .presentationCompactAdaptation(.popover)
                }

                Spacer()

                Button {
                    showInfo = true
                } label: {
                    StatusIcon(icon: "questionmark", color: .secondary)
                }
        }
        .font(.footnote.weight(.semibold))
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.tint(.blue.opacity(0.10)), in: .rect(cornerRadius: 0))
        .animation(.snappy, value: criticalAlertCount)
        .sheet(isPresented: $showInfo) {
            AppInfoView()
        }
    }

    private var homeBackground: some View {
        ZStack {
            Color(.systemBackground)

            Circle()
                .fill(Color.blue.opacity(0.35))
                .frame(width: 260, height: 260)
                .blur(radius: 80)
                .offset(x: -140, y: -280)

            Circle()
                .fill(Color.pink.opacity(0.3))
                .frame(width: 240, height: 240)
                .blur(radius: 90)
                .offset(x: 160, y: -80)

            Circle()
                .fill(Color.mint.opacity(0.3))
                .frame(width: 260, height: 260)
                .blur(radius: 90)
                .offset(x: -130, y: 420)

            Circle()
                .fill(Color.indigo.opacity(0.28))
                .frame(width: 240, height: 240)
                .blur(radius: 90)
                .offset(x: 140, y: 650)
        }
        .ignoresSafeArea()
    }

    private var criticalAlertCount: Int {
        appEnvironment.alertStore.unseenCriticalCount
    }

    private var meshColor: Color {
        switch appEnvironment.meshController.state {
        case .idle: return .gray
        case .searching: return .orange
        case .connected: return .green
        }
    }

    private var meshPeerCount: Int {
        if case .connected(let count) = appEnvironment.meshController.state {
            return count
        }
        return 0
    }

    private var meshStatusLabel: String {
        switch appEnvironment.meshController.state {
        case .idle: return "OFF"
        case .searching: return "SZUKA"
        case .connected(let count): return "\(count)"
        }
    }

    private var chatMessageCount: Int {
        unreadGeneralCount + unreadDirectCount
    }

    private var unreadGeneralCount: Int {
        appEnvironment.meshController.unreadGeneralCount
    }

    private var unreadDirectCount: Int {
        appEnvironment.meshController.unreadDirectCount
    }

    private var syncIcon: String {
        guard appEnvironment.connectivityMonitor.isOnline else { return "wifi.slash" }
        return appEnvironment.backendReporter.lastReportedAt != nil ? "checkmark.icloud.fill" : "icloud.slash"
    }

    private var syncColor: Color {
        guard appEnvironment.connectivityMonitor.isOnline else { return .red }
        return appEnvironment.backendReporter.lastReportedAt != nil ? .green : .orange
    }

    private var alertsPopoverMessage: String {
        let titles = appEnvironment.alertStore.criticalAlerts.prefix(2).map(\.title).joined(separator: "; ")
        let count = criticalAlertCount
        let headline = count == 1 ? "1 aktywny alert krytyczny." : "\(count) aktywnych alertów krytycznych."
        return titles.isEmpty ? headline : "\(headline) \(titles)."
    }

    private var meshPopoverMessage: String {
        switch appEnvironment.meshController.state {
        case .idle:
            return "Sieć MESH jest wyłączona. Uruchom ją, żeby łączyć się z innymi urządzeniami w zasięgu bez internetu."
        case .searching:
            return "Szukam urządzeń w zasięgu…"
        case .connected(let count):
            return count == 1 ? "Połączono z 1 urządzeniem." : "Połączono z \(count) urządzeniami."
        }
    }

    private var gpsPopoverMessage: String {
        appEnvironment.locationStatus.hasRecentFix
            ? "Masz aktualny sygnał GPS. Lokalizacja jest używana do mapy, SOS przez MESH i alertów w Twojej okolicy."
            : "Brak aktualnego sygnału GPS. Sprawdź, czy lokalizacja jest włączona dla tej aplikacji w Ustawieniach."
    }

    private var syncPopoverMessage: String {
        guard appEnvironment.connectivityMonitor.isOnline else {
            return "Brak połączenia z internetem. Dane nie mogą się teraz zsynchronizować z serwerem sztabu."
        }
        if let last = appEnvironment.backendReporter.lastReportedAt {
            return "Ostatnia synchronizacja z serwerem sztabu: \(last.formatted(date: .omitted, time: .shortened))."
        }
        return "Masz połączenie z internetem, ale jeszcze nie zsynchronizowano z serwerem sztabu."
    }
}

private enum HomeDestination: Identifiable {
    case alerts, mesh, map

    var id: Self { self }
}

private struct StatusPill: View {
    let title: LocalizedStringResource
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .contentTransition(.symbolEffect(.replace))

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 9)
        .frame(minHeight: 38)
        .glassEffect(.regular.tint(color.opacity(0.16)).interactive(), in: .capsule)
    }
}

private struct StatusIcon: View {
    let icon: String
    let color: Color
    var badge: Int = 0

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 38, height: 38)
            .glassEffect(.regular.tint(color.opacity(0.14)).interactive(), in: .circle)
            .overlay(alignment: .topTrailing) {
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(color, in: .circle)
                        .offset(x: 4, y: -3)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.snappy, value: badge)
    }
}

private struct StatusPopover: View {
    let icon: String
    let color: Color
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
            }

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(actionTitle, action: action)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.glassProminent)
                .tint(color)
        }
        .padding()
        .frame(minWidth: 260, idealWidth: 280)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(AppEnvironment())
}
