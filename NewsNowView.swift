import SwiftUI

struct NewsNowView: View {
    @State private var store = NewsNowStore()
    @State private var selectedCategory: NewsCategory?

    private var filteredItems: [NewsItem] {
        guard let selectedCategory else { return store.items }
        return store.items.filter { $0.category == selectedCategory }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                categoryFilter

                Group {
                    if filteredItems.isEmpty {
                        Text("Brak wiadomości w tej kategorii.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredItems) { item in
                                NewsRow(item: item)
                            }
                        }
                    }
                }
                .id(selectedCategory)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
            .padding()
            .animation(.snappy, value: selectedCategory)
        }
        .navigationTitle("News NOW")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("News NOW")
                .font(.largeTitle.weight(.bold))
            Text("Bieżące informacje z Twojej okolicy — komunikaty służb, stan infrastruktury i zgłoszenia mieszkańców.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(title: "Wszystkie", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(NewsCategory.allCases, id: \.self) { category in
                    categoryChip(title: category.rawValue, isSelected: selectedCategory == category) {
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                }
            }
        }
    }

    private func categoryChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(isSelected ? .white : .indigo)
                .background {
                    if isSelected {
                        Capsule().fill(Color.indigo)
                    }
                }
                .glassEffect(.regular.tint(.indigo.opacity(isSelected ? 0 : 0.14)), in: .capsule)
                .animation(.snappy, value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

private struct NewsRow: View {
    let item: NewsItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.category.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.indigo)
                .glassBadge(tint: .indigo, size: 38, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                Text(item.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(item.source)
                    Text("•")
                    Text(item.publishedAt, style: .relative)
                    Text("temu")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .glassCard(cornerRadius: 12)
    }
}

#Preview {
    NavigationStack {
        NewsNowView()
    }
}
