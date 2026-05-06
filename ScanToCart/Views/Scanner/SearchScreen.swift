import SwiftUI

struct SearchScreen: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""
    @State private var searchResults: [Product] = []
    @State private var selectedProduct: Product?
    @State private var isSearching = false
    @State private var isLoadingMore = false
    @State private var currentPage = 1
    @State private var hasMore = true
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                if searchText.trimmingCharacters(in: .whitespaces).count < 2 {
                    emptyState
                } else if isSearching && searchResults.isEmpty {
                    loadingState
                } else if searchResults.isEmpty {
                    noResults
                } else {
                    resultsList
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedProduct) { product in
                ProductDetailSheet(product: product)
                    .environment(store)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textSecondary)
            TextField("Search products by name", text: $searchText)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: searchText) { _, newValue in
                    debouncedSearch(newValue)
                }

            if isSearching {
                ProgressView()
                    .controlSize(.small)
            } else if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, product in
                    ProductCard(product: product, store: store.settings.preferredStore) {
                        selectedProduct = product
                    }
                    .onAppear {
                        if index >= searchResults.count - 5 {
                            loadMoreIfNeeded()
                        }
                    }
                }

                if isLoadingMore {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Loading more…")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.vertical, 16)
                } else if !hasMore && !searchResults.isEmpty {
                    Text("End of results")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 16)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textSecondary)
            Text("Search 4M+ products")
                .font(.headline)
                .foregroundStyle(Theme.textSecondary)
            Text("Try \"oat milk\", \"granola\", or a brand name")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Searching…")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var noResults: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textSecondary)
            Text("No products found")
                .font(.headline)
                .foregroundStyle(Theme.textSecondary)
            Text("Try a different term, or scan a barcode for an exact match")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func debouncedSearch(_ query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            searchResults = []
            isSearching = false
            currentPage = 1
            hasMore = true
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                isSearching = true
                currentPage = 1
                hasMore = true
            }
            let results = await store.search(query: trimmed, page: 1)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                searchResults = results
                isSearching = false
                hasMore = !results.isEmpty
            }
        }
    }

    private func loadMoreIfNeeded() {
        guard hasMore, !isLoadingMore, !isSearching else { return }
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return }

        isLoadingMore = true
        let nextPage = currentPage + 1
        Task {
            let more = await store.search(query: trimmed, page: nextPage)
            await MainActor.run {
                isLoadingMore = false
                if more.isEmpty {
                    hasMore = false
                } else {
                    let existingIDs = Set(searchResults.map(\.id))
                    let newOnes = more.filter { !existingIDs.contains($0.id) }
                    if newOnes.isEmpty {
                        hasMore = false
                    } else {
                        searchResults.append(contentsOf: newOnes)
                        currentPage = nextPage
                    }
                }
            }
        }
    }
}
