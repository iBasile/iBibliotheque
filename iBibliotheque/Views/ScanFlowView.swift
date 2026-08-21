import SwiftUI
import SwiftData

struct ScanFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Furniture.name) private var furnitures: [Furniture]

    @State private var selectedFurniture: Furniture?
    @State private var selectedShelfNumber: Int = 1
    @State private var isScanning = false
    @State private var pendingISBN: String?
    @State private var pendingMetadata: BookMetadata?
    @State private var isLookingUp = false
    @State private var lookupFailed = false
    @State private var newFurnitureName = ""
    @State private var showingNewFurnitureField = false

    private let lookupService = BookLookupService()

    var body: some View {
        NavigationStack {
            Form {
                Section("Meuble") {
                    Picker("Meuble", selection: $selectedFurniture) {
                        Text("Sélectionner").tag(Furniture?.none)
                        ForEach(furnitures) { furniture in
                            Text(furniture.name).tag(Furniture?.some(furniture))
                        }
                    }

                    if showingNewFurnitureField {
                        HStack {
                            TextField("Nom du nouveau meuble", text: $newFurnitureName)
                            Button("Créer") { createFurniture() }
                                .disabled(newFurnitureName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    } else {
                        Button("+ Nouveau meuble") { showingNewFurnitureField = true }
                    }
                }

                Section("Étagère (numérotée en partant du haut)") {
                    Stepper("Étagère n° \(selectedShelfNumber)", value: $selectedShelfNumber, in: 1...20)
                }

                Section {
                    Button {
                        isScanning = true
                    } label: {
                        Label("Commencer le scan", systemImage: "barcode.viewfinder")
                    }
                    .disabled(selectedFurniture == nil)
                }
            }
            .navigationTitle("Ajouter des livres")
            .fullScreenCover(isPresented: $isScanning) {
                scannerSheet
            }
        }
    }

    private var scannerSheet: some View {
        ZStack {
            BarcodeScannerView { isbn in
                // Ignore les scans supplémentaires tant qu'un résultat est en attente de confirmation.
                guard pendingISBN == nil else { return }
                pendingISBN = isbn
                Task { await handleScan(isbn: isbn) }
            }
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button("Terminer") { isScanning = false }
                        .padding()
                        .background(.thinMaterial, in: Capsule())
                        .padding()
                    Spacer()
                }
                Spacer()
                if isLookingUp {
                    ProgressView("Recherche en cours...")
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }

            if let metadata = pendingMetadata {
                confirmationOverlay(metadata: metadata)
            }

            if lookupFailed {
                failureOverlay
            }
        }
    }

    private func confirmationOverlay(metadata: BookMetadata) -> some View {
        VStack(spacing: 12) {
            CoverImageView(urlString: metadata.coverURLString)
                .frame(width: 80, height: 112)
            Text(metadata.title)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(metadata.author)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Source : \(metadata.source.rawValue)")
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack {
                Button("Ignorer") { resetPending() }
                    .buttonStyle(.bordered)
                Button("Ajouter") { addBook(metadata: metadata) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding()
    }

    private var failureOverlay: some View {
        VStack(spacing: 12) {
            Text("Livre non trouvé")
                .font(.headline)
            Text("ISBN : \(pendingISBN ?? "")")
                .font(.caption)
            Button("Réessayer un autre livre") { resetPending() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding()
    }

    private func handleScan(isbn: String) async {
        isLookingUp = true
        let result = await lookupService.lookup(isbn: isbn)
        isLookingUp = false

        if let result {
            pendingMetadata = result
        } else {
            lookupFailed = true
        }
    }

    private func addBook(metadata: BookMetadata) {
        guard let furniture = selectedFurniture else { return }
        let shelf = findOrCreateShelf(number: selectedShelfNumber, in: furniture)

        let book = Book(
            isbn: metadata.isbn,
            title: metadata.title,
            author: metadata.author,
            publisher: metadata.publisher,
            year: metadata.year,
            coverURLString: metadata.coverURLString,
            shelf: shelf
        )
        modelContext.insert(book)
        resetPending()
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

    private func createFurniture() {
        let name = newFurnitureName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let furniture = Furniture(name: name)
        modelContext.insert(furniture)
        selectedFurniture = furniture
        newFurnitureName = ""
        showingNewFurnitureField = false
    }

    private func resetPending() {
        pendingISBN = nil
        pendingMetadata = nil
        lookupFailed = false
    }
}
