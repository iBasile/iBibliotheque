import Foundation

enum BookSource: String {
    case bnf = "BnF"
    case googleBooks = "Google Books"
    case openLibrary = "Open Library"
}

/// Modèle unifié : peu importe la source, le reste de l'app manipule toujours ce type.
struct BookMetadata {
    var isbn: String
    var title: String
    var author: String
    var publisher: String
    var year: String
    var coverURLString: String?
    var source: BookSource
}
