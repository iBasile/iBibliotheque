import Foundation

enum CSVExporter {

    static func export(furnitures: [Furniture]) -> URL? {
        var rows: [[String]] = [
            ["Titre", "Auteur", "ISBN", "Éditeur", "Année", "Meuble", "Étagère", "Date d'ajout"]
        ]

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short

        for furniture in furnitures {
            for shelf in furniture.shelves.sorted(by: { $0.number < $1.number }) {
                for book in shelf.books {
                    rows.append([
                        book.title,
                        book.author,
                        book.isbn,
                        book.publisher,
                        book.year,
                        furniture.name,
                        String(shelf.number),
                        dateFormatter.string(from: book.dateAdded)
                    ])
                }
            }
        }

        let csvBody = rows.map { row in
            row.map(escape).joined(separator: ",")
        }.joined(separator: "\n")

        // Le BOM UTF-8 assure un affichage correct des accents dans Excel.
        let finalString = "\u{FEFF}" + csvBody

        guard let data = finalString.data(using: .utf8) else { return nil }

        let filename = "bibliotheque-\(Int(Date().timeIntervalSince1970)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: url)
            return url
        } catch {
            print("Erreur export CSV : \(error)")
            return nil
        }
    }

    private static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }
}
