import SwiftUI
import CoreLocation

struct FirstAidStep: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

struct FirstAidStepRow: View {
    let index: Int
    let step: FirstAidStep
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: step.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(tint)
                    .glassBadge(tint: tint, size: 44, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("\(index)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(tint)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color(.systemBackground), lineWidth: 2))
                    .offset(x: 7, y: 7)
            }
            .padding(.trailing, 4)
            .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.subheadline.weight(.semibold))
                Text(step.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct FirstAidWarningBox: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(text)
                .font(.footnote.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: .red, cornerRadius: 12)
    }
}

struct EmergencyCallButton: View {
    var body: some View {
        Button {
            if let url = URL(string: "tel://112") {
                UIApplication.shared.open(url)
            }
        } label: {
            Label("Zadzwoń pod 112", systemImage: "phone.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.glassProminent)
        .tint(.red)
    }
}

/// A small square icon button for placing "call 112" right next to a section's header pictogram,
/// where there isn't room (or need) for a full-width labeled button.
struct CompactEmergencyCallButton: View {
    var body: some View {
        Button {
            if let url = URL(string: "tel://112") {
                UIApplication.shared.open(url)
            }
        } label: {
            Image(systemName: "phone.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.red)
                .glassBadge(tint: .red, size: 52, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.tilePress)
    }
}

struct SOSReport {
    let timestamp: Date
    let latitude: Double?
    let longitude: Double?

    var coordinateText: String {
        guard let latitude, let longitude else {
            return "Lokalizacja nieznana (brak dostępu do GPS)"
        }
        return String(format: "%.4f, %.4f", latitude, longitude)
    }
}

/// Drives a one-shot location request and the lifecycle of a critical MESH SOS report:
/// idle → sending → sent (delivered to the mesh) → acknowledged (a rescue service picked it up).
/// There's no real mesh transport yet (see `CommunicationView`), so delivery and the
/// service acknowledgment are simulated locally with realistic timing; swapping in a real
/// mesh call later only touches `finishSending`/the acknowledgment trigger, not the UI.
@MainActor
@Observable
final class MeshSOSReporter: NSObject {
    enum Status: Equatable {
        case idle
        case sending
        case sent
        case acknowledged
    }

    private(set) var status: Status = .idle
    private(set) var report: SOSReport?
    private(set) var sentAt: Date?
    private(set) var acknowledgedAt: Date?

    @ObservationIgnored private lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = self
        return manager
    }()

    @ObservationIgnored private var acknowledgeWorkItem: DispatchWorkItem?

    func sendSOS() {
        guard status == .idle || status == .acknowledged else { return }
        acknowledgeWorkItem?.cancel()
        report = nil
        sentAt = nil
        acknowledgedAt = nil
        status = .sending

        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            finishSending(latitude: nil, longitude: nil)
        @unknown default:
            finishSending(latitude: nil, longitude: nil)
        }
    }

    private func finishSending(latitude: Double?, longitude: Double?) {
        report = SOSReport(timestamp: .now, latitude: latitude, longitude: longitude)
        sentAt = .now
        status = .sent

        // TODO: replace with a real acknowledgment coming back over the mesh network once it exists.
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.status == .sent else { return }
            self.acknowledgedAt = .now
            self.status = .acknowledged
        }
        acknowledgeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: workItem)
    }
}

extension MeshSOSReporter: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.finishSending(latitude: locations.last?.coordinate.latitude, longitude: locations.last?.coordinate.longitude)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.finishSending(latitude: nil, longitude: nil)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard self.status == .sending else { return }
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                self.finishSending(latitude: nil, longitude: nil)
            case .notDetermined:
                break
            @unknown default:
                self.finishSending(latitude: nil, longitude: nil)
            }
        }
    }
}

struct MeshSOSButton: View {
    @State private var reporter = MeshSOSReporter()

    var body: some View {
        VStack(spacing: 12) {
            Button {
                reporter.sendSOS()
            } label: {
                HStack {
                    icon
                    Text(title)
                        .contentTransition(.opacity)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .animation(.default, value: reporter.status)
            }
            .buttonStyle(.glassProminent)
            .tint(.blue)
            .disabled(reporter.status == .sending || reporter.status == .sent)

            Group {
                if reporter.status == .idle {
                    Text("Wyśle krytyczny sygnał SOS wraz z Twoją lokalizacją GPS do urządzeń w zasięgu sieci MESH.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    statusCard
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
            .animation(.snappy, value: reporter.status)
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch reporter.status {
        case .idle:
            Image(systemName: "antenna.radiowaves.left.and.right")
        case .sending:
            ProgressView()
                .tint(.white)
        case .sent:
            Image(systemName: "paperplane.fill")
        case .acknowledged:
            Image(systemName: "checkmark.circle.fill")
        }
    }

    private var title: String {
        switch reporter.status {
        case .idle:
            return "Wyślij SOS przez MESH"
        case .sending:
            return "Wysyłanie zgłoszenia SOS…"
        case .sent:
            return "Zgłoszenie SOS wysłane"
        case .acknowledged:
            return "Wyślij nowe zgłoszenie"
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PRIORYTET: KRYTYCZNY")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                Spacer()
            }

            statusRow(
                icon: "paperplane.fill",
                tint: .blue,
                title: "Zgłoszenie SOS wysłane do sieci MESH",
                detail: reporter.report?.coordinateText,
                timestamp: reporter.sentAt
            )

            Group {
                if reporter.status == .acknowledged {
                    statusRow(
                        icon: "checkmark.seal.fill",
                        tint: .green,
                        title: "Odczytano — służby podjęły się udzielenia pomocy",
                        detail: nil,
                        timestamp: reporter.acknowledgedAt
                    )
                } else {
                    statusRow(
                        icon: "hourglass",
                        tint: .orange,
                        title: "Oczekiwanie na potwierdzenie odczytu przez służby…",
                        detail: nil,
                        timestamp: nil
                    )
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
            .animation(.snappy, value: reporter.status)
        }
        .padding(12)
        .glassCard(tint: .blue, cornerRadius: 12)
    }

    private func statusRow(icon: String, tint: Color, title: String, detail: String?, timestamp: Date?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let timestamp {
                    Text(timestamp.formatted(date: .omitted, time: .standard))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// A small square icon button — same footprint as `CompactEmergencyCallButton` — for placing SOS
/// right next to a section's header pictogram. Tapping it sends the SOS (same as `MeshSOSButton`)
/// and opens a small popover with live status instead of an always-expanded card, so it stays
/// compact when idle.
struct CompactMeshSOSButton: View {
    let reporter: MeshSOSReporter
    @State private var showPopover = false

    var body: some View {
        Button {
            if reporter.status == .idle || reporter.status == .acknowledged {
                reporter.sendSOS()
            }
            showPopover = true
        } label: {
            iconBadge
        }
        .buttonStyle(.tilePress)
        .popover(isPresented: $showPopover) {
            popoverContent
                .presentationCompactAdaptation(.popover)
        }
    }

    private var color: Color {
        switch reporter.status {
        case .idle: return .blue
        case .sending, .sent: return .orange
        case .acknowledged: return .green
        }
    }

    @ViewBuilder
    private var iconBadge: some View {
        Group {
            switch reporter.status {
            case .idle:
                Image(systemName: "antenna.radiowaves.left.and.right")
            case .sending:
                ProgressView()
                    .tint(color)
            case .sent:
                Image(systemName: "paperplane.fill")
            case .acknowledged:
                Image(systemName: "checkmark.circle.fill")
            }
        }
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(color)
        .glassBadge(tint: color, size: 52, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.default, value: reporter.status)
    }

    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PRIORYTET: KRYTYCZNY")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                Spacer()
            }

            Text(statusTitle)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            if let report = reporter.report {
                Text(report.coordinateText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let sentAt = reporter.sentAt {
                Text("Wysłano: \(sentAt.formatted(date: .omitted, time: .standard))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let acknowledgedAt = reporter.acknowledgedAt {
                Text("Odczytano: \(acknowledgedAt.formatted(date: .omitted, time: .standard))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .frame(minWidth: 250, idealWidth: 270)
    }

    private var statusTitle: String {
        switch reporter.status {
        case .idle:
            return "Naciśnij, aby wysłać krytyczny sygnał SOS wraz z Twoją lokalizacją do sieci MESH."
        case .sending:
            return "Wysyłanie zgłoszenia SOS…"
        case .sent:
            return "Zgłoszenie SOS wysłane do sieci MESH. Oczekiwanie na potwierdzenie przez służby…"
        case .acknowledged:
            return "Odczytano — służby podjęły się udzielenia pomocy."
        }
    }
}

/// A persistent status card for the same `MeshSOSReporter` a `CompactMeshSOSButton` drives —
/// meant to sit lower on the page (where a full-size SOS button used to be) so the report's status
/// stays visible on scroll, in addition to the popover that appears right when you tap the icon.
struct MeshSOSStatusCard: View {
    let reporter: MeshSOSReporter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PRIORYTET: KRYTYCZNY")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                Spacer()
            }

            Text("Status zgłoszenia SOS przez MESH")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Group {
                switch reporter.status {
                case .idle:
                    Text("Nie wysłano jeszcze zgłoszenia. Użyj przycisku z anteną obok nagłówka, aby wysłać SOS wraz z lokalizacją.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                default:
                    VStack(alignment: .leading, spacing: 10) {
                        statusRow(
                            icon: "paperplane.fill",
                            tint: .blue,
                            title: "Zgłoszenie SOS wysłane do sieci MESH",
                            detail: reporter.report?.coordinateText,
                            timestamp: reporter.sentAt
                        )

                        if reporter.status == .acknowledged {
                            statusRow(
                                icon: "checkmark.seal.fill",
                                tint: .green,
                                title: "Odczytano — służby podjęły się udzielenia pomocy",
                                detail: nil,
                                timestamp: reporter.acknowledgedAt
                            )
                        } else {
                            statusRow(
                                icon: "hourglass",
                                tint: .orange,
                                title: "Oczekiwanie na potwierdzenie odczytu przez służby…",
                                detail: nil,
                                timestamp: nil
                            )
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .animation(.snappy, value: reporter.status)
                }
            }
            .transition(.opacity)
            .animation(.snappy, value: reporter.status)
        }
        .padding(12)
        .glassCard(tint: .blue, cornerRadius: 12)
    }

    private func statusRow(icon: String, tint: Color, title: String, detail: String?, timestamp: Date?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let timestamp {
                    Text(timestamp.formatted(date: .omitted, time: .standard))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
