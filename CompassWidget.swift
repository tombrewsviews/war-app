import SwiftUI
import CoreLocation

@MainActor
@Observable
final class CompassHeadingProvider: NSObject {
    private(set) var headingDegrees: Double = 0
    let isAvailable = CLLocationManager.headingAvailable()

    @ObservationIgnored private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func start() {
        guard isAvailable else { return }
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        locationManager.startUpdatingHeading()
    }

    func stop() {
        locationManager.stopUpdatingHeading()
    }
}

extension CompassHeadingProvider: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in
            self.headingDegrees = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        }
    }
}

/// A compass dial pinned as a permanent overlay wherever it's used — per the requirement that the
/// compass must always be visible in the Mapa i Kompas section, not just on a tab you switch to.
struct CompassWidget: View {
    @State private var provider = CompassHeadingProvider()

    private let ticks: [(label: String, angle: Double)] = [("N", 0), ("E", 90), ("S", 180), ("W", 270)]

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.purple.opacity(0.3), lineWidth: 1.5)

            ForEach(ticks, id: \.label) { tick in
                Text(tick.label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tick.label == "N" ? Color.red : Color.gray)
                    .offset(y: -28)
                    .rotationEffect(.degrees(tick.angle))
            }
            .rotationEffect(.degrees(-provider.headingDegrees))

            Image(systemName: "location.north.fill")
                .font(.system(size: 16))
                .foregroundStyle(.purple)
        }
        .frame(width: 68, height: 68)
        .padding(3)
        .overlay(alignment: .bottom) {
            if !provider.isAvailable {
                Text("brak czujnika")
                    .font(.system(size: 7))
                    .foregroundStyle(.secondary)
                    .offset(y: 10)
            }
        }
        .glassEffect(.regular.tint(.purple.opacity(0.08)), in: .circle)
        .onAppear { provider.start() }
        .onDisappear { provider.stop() }
    }
}

#Preview {
    CompassWidget()
        .padding()
}
