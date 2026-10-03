import Foundation

enum NewsCategory: String, CaseIterable {
    case security = "Bezpieczeństwo"
    case infrastructure = "Infrastruktura"
    case official = "Komunikat oficjalny"
    case community = "Społeczność"

    var icon: String {
        switch self {
        case .security: return "shield.lefthalf.filled"
        case .infrastructure: return "bolt.fill"
        case .official: return "checkmark.seal.fill"
        case .community: return "person.3.fill"
        }
    }
}

struct NewsItem: Identifiable {
    let id = UUID()
    let title: String
    let summary: String
    let category: NewsCategory
    let publishedAt: Date
    let source: String
}

/// Seeded local mock feed for now. This is the natural place to later plug in the "AI agent that
/// scrapes and filters government/news portals" idea from earlier — the console/backend would push
/// items here the same way it already can for alerts, and this store would just start rendering them.
@MainActor
@Observable
final class NewsNowStore {
    private(set) var items: [NewsItem]

    init() {
        let now = Date.now
        items = [
            NewsItem(
                title: "Alarm przeciwlotniczy odwołany dla dzielnicy Centrum",
                summary: "Zagrożenie minęło. Służby potwierdzają, że można bezpiecznie wrócić do normalnych zajęć w tej części miasta.",
                category: .official,
                publishedAt: now.addingTimeInterval(-30 * 60),
                source: "RCB"
            ),
            NewsItem(
                title: "Dostawa wody pitnej w punkcie przy ul. Długiej 12",
                summary: "Od godziny 14:00 dostępna jest darmowa woda pitna. Prosimy zabrać własne pojemniki.",
                category: .infrastructure,
                publishedAt: now.addingTimeInterval(-90 * 60),
                source: "Straż Miejska"
            ),
            NewsItem(
                title: "Schron przy Szkole nr 4 otwarty całą dobę",
                summary: "Obiekt przyjmuje osoby potrzebujące schronienia bez ograniczeń godzinowych do odwołania.",
                category: .official,
                publishedAt: now.addingTimeInterval(-3 * 60 * 60),
                source: "Urząd Miasta"
            ),
            NewsItem(
                title: "Utrudnienia w sieci komórkowej w dzielnicy Wschodniej",
                summary: "Operatorzy zgłaszają przeciążenie sieci. W razie problemów z połączeniem korzystaj z komunikacji Mesh w aplikacji.",
                category: .infrastructure,
                publishedAt: now.addingTimeInterval(-5 * 60 * 60),
                source: "UKE"
            ),
            NewsItem(
                title: "Mieszkańcy organizują wspólne warty sąsiedzkie",
                summary: "W kilku dzielnicach mieszkańcy ustalili grafik wzajemnego wsparcia i pilnowania bezpieczeństwa klatek schodowych.",
                category: .community,
                publishedAt: now.addingTimeInterval(-8 * 60 * 60),
                source: "Zgłoszenie mieszkańca"
            ),
            NewsItem(
                title: "Wzmożone patrole w rejonie dzielnicy Wschodniej",
                summary: "Służby apelują o zachowanie ostrożności po zmroku i zgłaszanie podejrzanych osób lub pojazdów przez numer 112.",
                category: .security,
                publishedAt: now.addingTimeInterval(-2 * 60 * 60),
                source: "Policja"
            )
        ]
    }
}
