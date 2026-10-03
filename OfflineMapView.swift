import SwiftUI
import MapKit

struct OfflineMapView: View {
    @State private var mapCache = OfflineMapCache()
    @State private var riverStore = RiverCrossingStore()
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedBridge: Bridge?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            mapContent
                .ignoresSafeArea(edges: .bottom)

            CompassWidget()
                .padding()
        }
        .safeAreaInset(edge: .top) {
            statusBanner
        }
        .navigationTitle("Mapa i kompas")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { mapCache.start() }
        .onDisappear { mapCache.stop() }
        .sheet(item: $selectedBridge) { bridge in
            BridgeDetailSheet(
                bridge: bridge,
                recommendation: riverStore.recommendation(for: bridge)
            ) {
                riverStore.toggleBridgeStatus(bridge)
                selectedBridge = nil
            }
        }
    }

    @ViewBuilder
    private var mapContent: some View {
        if mapCache.isOffline {
            if let coordinate = mapCache.currentCoordinate, let image = mapCache.cachedImage(near: coordinate) {
                offlineImageView(image)
            } else {
                offlineUnavailablePlaceholder
            }
        } else {
            liveMapView
        }
    }

    private var liveMapView: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()

            ForEach(riverStore.bridges) { bridge in
                Annotation(bridge.name, coordinate: bridge.coordinate) {
                    // A `Button` here needs two taps on some MapKit/SwiftUI versions — the map's own
                    // gesture recognizer eats the first one. A plain tap gesture fires reliably on tap 1.
                    Image(systemName: bridge.status == .intact ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .font(.title3)
                        .foregroundStyle(bridge.status == .intact ? .green : .red)
                        .padding(6)
                        .background(Circle().fill(.white))
                        .contentShape(Circle())
                        .onTapGesture {
                            selectedBridge = bridge
                        }
                }
            }

            ForEach(riverStore.crossingPoints) { point in
                Annotation(point.name, coordinate: point.coordinate) {
                    Image(systemName: "figure.walk")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                        .padding(6)
                        .background(Circle().fill(.white))
                }
            }

            ForEach(riverStore.hazards) { hazard in
                Annotation(hazard.title, coordinate: hazard.coordinate) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(hazard.severity.color)
                        .padding(6)
                        .background(Circle().fill(.white))
                }
            }
        }
        .mapStyle(.standard)
    }

    private func offlineImageView(_ image: UIImage) -> some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
        .overlay(alignment: .bottom) {
            Text("Offline — wyświetlam zapisaną mapę")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.black.opacity(0.6))
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .padding(.bottom, 30)
        }
    }

    private var offlineUnavailablePlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Brak połączenia i brak jeszcze zapisanej mapy dla tego obszaru.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemBackground))
    }

    private var statusBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .contentTransition(.symbolEffect(.replace))
            Text(statusText)
                .font(.caption.weight(.semibold))
                .contentTransition(.opacity)
            Spacer()
            if mapCache.authorizationStatus == .denied || mapCache.authorizationStatus == .restricted {
                Button("Ustawienia") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption.weight(.semibold))
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular.tint(statusColor.opacity(0.14)), in: .rect(cornerRadius: 0))
        .animation(.default, value: statusIcon)
        .animation(.default, value: statusText)
    }

    private var statusIcon: String {
        switch mapCache.authorizationStatus {
        case .denied, .restricted: return "location.slash"
        default: break
        }
        if mapCache.isDownloading { return "arrow.down.circle" }
        if mapCache.lastDownloadError != nil { return "exclamationmark.triangle.fill" }
        if mapCache.isOffline { return "wifi.slash" }
        if mapCache.cachedRegions.isEmpty { return "clock" }
        return "checkmark.circle.fill"
    }

    private var statusColor: Color {
        switch mapCache.authorizationStatus {
        case .denied, .restricted: return .red
        default: break
        }
        if mapCache.isDownloading { return .orange }
        if mapCache.lastDownloadError != nil { return .orange }
        if mapCache.isOffline { return .red }
        if mapCache.cachedRegions.isEmpty { return .secondary }
        return .green
    }

    private var statusText: String {
        switch mapCache.authorizationStatus {
        case .denied, .restricted:
            return "Brak dostępu do lokalizacji — włącz go, aby pobierać mapę offline."
        default:
            break
        }

        if mapCache.isDownloading {
            return "Pobieranie mapy offline (10 km)…"
        }
        if let error = mapCache.lastDownloadError {
            return "\(error) Ponawiam automatycznie…"
        }
        if let latest = mapCache.cachedRegions.max(by: { $0.savedAt < $1.savedAt }) {
            let time = latest.savedAt.formatted(date: .omitted, time: .shortened)
            return mapCache.isOffline ? "Offline — ostatnia mapa pobrana \(time)" : "Obszar 10 km pobrany: \(time)"
        }
        return mapCache.isOffline ? "Offline — mapa jeszcze niedostępna" : "Mapa offline jeszcze niedostępna"
    }
}

struct BridgeDetailSheet: View {
    let bridge: Bridge
    let recommendation: CrossingRecommendation?
    let onToggleStatus: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: bridge.status == .intact ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .font(.title2)
                        .foregroundStyle(bridge.status == .intact ? .green : .red)
                    Text(bridge.name)
                        .font(.title2.weight(.bold))
                }

                Text(bridge.status == .intact ? "Most przejezdny." : "Most zniszczony / nieprzejezdny.")
                    .foregroundStyle(.secondary)

                if bridge.status == .destroyed {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Zalecana trasa alternatywna")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        if let recommendation {
                            Text(recommendation.title)
                                .font(.headline)
                            Text(recommendation.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Brak znanych alternatyw w okolicy.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(tint: .orange, cornerRadius: 12)
                }

                Button(bridge.status == .intact ? "Oznacz jako zniszczony" : "Oznacz jako przejezdny") {
                    onToggleStatus()
                }
                .buttonStyle(.glass)
                .tint(bridge.status == .intact ? .red : .green)

                Spacer()
            }
            .padding()
            .navigationTitle("Most")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        OfflineMapView()
    }
}
