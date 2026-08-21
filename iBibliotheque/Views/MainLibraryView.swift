import SwiftUI
import SwiftData

/// Fichier CSV exporté, enveloppé pour être Identifiable et utilisable avec .sheet(item:)
private struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

struct MainLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Furniture.name) private var furnitures: [Furniture]

    @State private var exportFile: ExportFile?
    @State private var selectedBook: Book?
    @State private var furnitureToDelete: Furniture?

    var body: some View {
        NavigationStack {
            Group {
                if furnitures.isEmpty {
                    ContentUnavailableView(
                        "Aucun livre",
                        systemImage: "books.vertical",
                        description: Text("Utilise l'onglet Scanner pour ajouter tes premiers livres.")
                    )
                } else {
                    List {
                        ForEach(furnitures) { furniture in
                            Section {
                                ForEach(furniture.shelves.sorted(by: { $0.number < $1.number })) { shelf in
                                    DisclosureGroup("Étagère \(shelf.number) (\(shelf.books.count))") {
                                        ForEach(shelf.books.sorted(by: { $0.title < $1.title })) { book in
                                            Button {
                                                selectedBook = book
                                            } label: {
                                                bookRow(book)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            } header: {
                                furnitureHeader(furniture)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Ma bibliothèque")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if let url = CSVExporter.export(furnitures: furnitures) {
                            exportFile = ExportFile(url: url)
                        }
                    } label: {
                        Label("Exporter", systemImage: "square.and.arrow.up")
                    }
                    .disabled(furnitures.isEmpty)
                }
            }
            .sheet(item: $exportFile) { file in
                ShareLink(item: file.url) {
                    Label("Partager le fichier CSV", systemImage: "square.and.arrow.up")
                        .font(.headline)
                }
                .padding()
                .presentationDetents([.height(140)])
            }
            .sheet(item: $selectedBook) { book in
                BookDetailView(book: book)
            }
            .confirmationDialog(
                "Supprimer le meuble \"\(furnitureToDelete?.name ?? "")\" ?",
                isPresented: Binding(
                    get: { furnitureToDelete != nil },
                    set: { isPresented in if !isPresented { furnitureToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Supprimer", role: .destructive) {
                    if let furniture = furnitureToDelete {
                        modelContext.delete(furniture)
                    }
                    furnitureToDelete = nil
                }
                Button("Annuler", role: .cancel) { furnitureToDelete = nil }
            }
        }
    }

    private func bookRow(_ book: Book) -> some View {
        HStack(spacing: 12) {
            CoverImageView(urlString: book.coverURLString)
                .frame(width: 40, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .foregroundStyle(.primary)
                Text(book.author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func furnitureHeader(_ furniture: Furniture) -> some View {
        HStack {
            Text(furniture.name)
            Spacer()
            // Un meuble ne peut être supprimé que si toutes ses étagères sont vides.
            if isEmpty(furniture) {
                Button {
                    furnitureToDelete = furniture
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func isEmpty(_ furniture: Furniture) -> Bool {
        furniture.shelves.allSatisfy { $0.books.isEmpty }
    }
}
