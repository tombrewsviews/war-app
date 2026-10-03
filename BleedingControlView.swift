import SwiftUI

struct BleedingControlView: View {
    private let steps: [FirstAidStep] = [
        FirstAidStep(
            icon: "shield.fill",
            title: "Zadbaj o bezpieczeństwo",
            description: "Usuń poszkodowanego z zagrożenia, jeśli to możliwe. Załóż rękawiczki, jeśli masz je pod ręką."
        ),
        FirstAidStep(
            icon: "eye.fill",
            title: "Oceń krwawienie",
            description: "Odsłoń ranę. Krwawienie tryskające, pulsujące lub szybko przesiąkające ubranie jest zagrażające życiu i wymaga natychmiastowego działania."
        ),
        FirstAidStep(
            icon: "hand.point.down.fill",
            title: "Uciśnij ranę",
            description: "Mocno dociśnij ranę czystym materiałem lub opatrunkiem, najlepiej obiema rękami. Nie przerywaj ucisku, by sprawdzić, czy krwawienie ustało."
        ),
        FirstAidStep(
            icon: "bandage.fill",
            title: "Krwawienie nie ustaje? Załóż opaskę zaciskową",
            description: "Przy masywnym krwotoku z kończyny zaciśnij opaskę taktyczną 5–7 cm powyżej rany (nie na stawie). Dokręcaj, aż krwawienie ustanie – będzie to bolesne, ale konieczne. Zapisz godzinę założenia, np. flamastrem na czole poszkodowanego."
        ),
        FirstAidStep(
            icon: "cross.case.fill",
            title: "Opatrunek uciskowy",
            description: "Gdy krwawienie ustanie, załóż opatrunek uciskowy i unieruchom kończynę, najlepiej uniesioną ponad poziom serca."
        ),
        FirstAidStep(
            icon: "waveform.path.ecg",
            title: "Obserwuj oznaki wstrząsu",
            description: "Bladość, zlewny pot, przyspieszone tętno, splątanie – ułóż poszkodowanego na płask z lekko uniesionymi nogami i okryj, by nie stracił ciepła."
        ),
        FirstAidStep(
            icon: "phone.fill",
            title: "Wezwij pomoc",
            description: "Zadzwoń pod 112 lub jak najszybciej przetransportuj poszkodowanego do punktu medycznego."
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
                    FirstAidWarningBox(text: "NIE zdejmuj opaski zaciskowej po jej założeniu — to zrobi wyłącznie personel medyczny.")
                    FirstAidWarningBox(text: "NIE wyciągaj przedmiotów wbitych w ranę — ustabilizuj je opatrunkiem wokół, nie na nich.")
                }

                EmergencyCallButton()

                MeshSOSButton()
            }
            .padding()
        }
        .navigationTitle("Krwawienie")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "bandage.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.red)
                .glassBadge(tint: .red, size: 60, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text("Tamowanie krwotoku")
                .font(.title.weight(.bold))
            Text("Postępuj krok po kroku. Przy masywnym krwawieniu liczy się każda sekunda.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        BleedingControlView()
    }
}
