import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Furniture.name) private var furnitures: [Furniture]

    let book: Book

    @State private var selectedFurniture: Furniture?
    @State private var selectedShelfNumber: Int = 1
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        CoverImageView(urlString: book.coverURLString)
                            .frame(width: 120, height: 170)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)

                Section("Informations") {
                    LabeledContent("Titre", value: book.title)
                    LabeledContent("Auteur", value: book.author)
                    LabeledContent("Éditeur", value: book.publisher.isEmpty ? "—" : book.publisher)
                    LabeledContent("Année", value: book.year.isEmpty ? "—" : book.year)
                    LabeledContent("ISBN", value: book.isbn)
                }

                Section("Déplacer vers") {
                    Picker("Meuble", selection: $selectedFurniture) {
                        ForEach(furnitures) { furniture in
                            Text(furniture.name).tag(Furniture?.some(furniture))
                        }
                    }
                    Stepper("Étagère n° \(selectedShelfNumber)", value: $selectedShelfNumber, in: 1...20)

                    Button("Déplacer ici") { moveBook() }
                        .disabled(selectedFurniture == nil || isSameLocation)
                }

                Section {
                    Button("Supprimer ce livre", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
            .navigationTitle(book.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .onAppear {
                selectedFurniture = book.shelf?.furniture
                selectedShelfNumber = book.shelf?.number ?? 1
            }
            .confirmationDialog(
                "Supprimer définitivement ce livre ?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Supprimer", role: .destructive) { deleteBook() }
                Button("Annuler", role: .cancel) {}
            }
        }
    }

    private var isSameLocation: Bool {
        selectedFurniture == book.shelf?.furniture && selectedShelfNumber == book.shelf?.number
    }

    private func moveBook() {
        guard let furniture = selectedFurniture else { return }
        book.shelf = findOrCreateShelf(number: selectedShelfNumber, in: furniture)
        dismiss()
    }

    private func findOrCreateShelf(number: Int, in furniture: Furniture) -> Shelf {
        if let existing = furniture.shelves.first(where: { $0.number == number }) {
            return existing
        }
        let shelf = Shelf(number: number, furniture: furniture)
        modelContext.insert(shelf)
        furniture.shelves.append(shelf)
        return shelf
    }

    private func deleteBook() {
        modelContext.delete(book)
        dismiss()
    }
}
