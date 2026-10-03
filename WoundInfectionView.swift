import SwiftUI

struct WoundInfectionView: View {
    private let steps: [FirstAidStep] = [
        FirstAidStep(
            icon: "drop.fill",
            title: "Oczyść ranę",
            description: "Przemyj czystą (najlepiej przegotowaną i ostudzoną) wodą. Usuń widoczne zabrudzenia. Umyj też swoje ręce przed opatrywaniem."
        ),
        FirstAidStep(
            icon: "bandage.fill",
            title: "Odkaź i osłoń",
            description: "Jeśli masz środek odkażający — użyj go. Jeśli nie, samo dokładne mycie wodą z mydłem jest i tak najważniejszym krokiem. Osłoń ranę czystym, suchym opatrunkiem."
        ),
        FirstAidStep(
            icon: "leaf.fill",
            title: "Miód jako naturalny opatrunek",
            description: "Surowy miód ma udokumentowane właściwości antybakteryjne i bywa stosowany klinicznie na rany. Cienka warstwa pod czystym opatrunkiem może pomóc, gdy nie masz dostępu do maści z apteki."
        ),
        FirstAidStep(
            icon: "eye.fill",
            title: "Obserwuj oznaki infekcji",
            description: "Narastające zaczerwienienie, obrzęk, ropa, silny ból, gorączka lub czerwone smugi rozchodzące się od rany wzdłuż kończyny — to sygnały, że infekcja się rozwija."
        ),
        FirstAidStep(
            icon: "exclamationmark.octagon.fill",
            title: "Dlaczego NIE hodować własnej „penicyliny”",
            description: "Domowa hodowla pleśni na chlebie czy owocach jest niebezpieczna: łatwo pomylić Penicillium z pleśnią toksyczną, nie da się kontrolować dawki ani czystości, a błędne dawkowanie antybiotyku grozi wstrząsem alergicznym lub zatruciem. To też fałszywe poczucie bezpieczeństwa, które może opóźnić szukanie prawdziwej pomocy."
        ),
        FirstAidStep(
            icon: "pills.fill",
            title: "Przygotuj się zawczasu, legalnie",
            description: "Najlepszy czas na skompletowanie apteczki kryzysowej z prawdziwymi lekami (w tym, po konsultacji z lekarzem, ewentualnym zapasowym antybiotykiem) jest teraz — zanim sytuacja stanie się krytyczna."
        ),
        FirstAidStep(
            icon: "phone.fill",
            title: "Kiedy to stan nagły",
            description: "Wysoka gorączka razem z szybko rozprzestrzeniającym się zaczerwienieniem lub splątaniem to może być sepsa — stan zagrożenia życia. Szukaj pomocy medycznej natychmiast, nie czekaj i nie lecz się sam."
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                VStack(alignment: .leading, spacing: 20) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        FirstAidStepRow(index: index + 1, step: step, tint: .red)
                    }
                }

                VStack(spacing: 10) {
                    FirstAidWarningBox(text: "NIE stosuj domowej roboty „antybiotyków” z pleśni — ryzyko zatrucia i wstrząsu jest większe niż potencjalna korzyść.")
                    FirstAidWarningBox(text: "Rana głęboka, mocno zabrudzona, po ugryzieniu zwierzęcia lub niegojąca się od kilku dni — traktuj priorytetowo i szukaj prawdziwej opieki medycznej.")
                }

                EmergencyCallButton()
            }
            .padding()
        }
        .navigationTitle("Rany i infekcje")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "bandage.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.red)
                .glassBadge(tint: .red, size: 52, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("Rany i infekcje")
                .font(.title.weight(.bold))
            Text("Bez dostępu do szpitala najważniejsza jest higiena rany i wczesne rozpoznanie infekcji — nie samodzielne leczenie antybiotykami.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        WoundInfectionView()
    }
}
