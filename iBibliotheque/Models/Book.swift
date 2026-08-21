import Foundation
import SwiftData

/// Représente un exemplaire physique de livre.
/// Deux exemplaires du même ISBN = deux instances distinctes de `Book`.
@Model
final class Book {
    var id: UUID
    var isbn: String
    var title: String
    var author: String
    var publisher: String
    var year: String
    var coverURLString: String?
    var dateAdded: Date
    var shelf: Shelf?

    init(
        isbn: String,
        title: String,
        author: String,
        publisher: String,
        year: String,
        coverURLString: String? = nil,
        shelf: Shelf? = nil
    ) {
        self.id = UUID()
        self.isbn = isbn
        self.title = title
        self.author = author
        self.publisher = publisher
        self.year = year
        self.coverURLString = coverURLString
        self.dateAdded = Date()
        self.shelf = shelf
    }
}
