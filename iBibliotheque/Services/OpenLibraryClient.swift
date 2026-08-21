import Foundation

/// Client pour l'API publique Open Library (Internet Archive).
/// Utilisé en dernier recours dans la cascade de recherche.
final class OpenLibraryClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private struct BookData: Codable {
        let title: String?
        let authors: [AuthorInfo]?
        let publishers: [PublisherInfo]?
        let publish_date: String?
        let cover: CoverInfo?

        struct AuthorInfo: Codable { let name: String? }
        struct PublisherInfo: Codable { let name: String? }
        struct CoverInfo: Codable { let large: String? }
    }

    func lookup(isbn: String) async throws -> BookMetadata? {
        let cleaned = ISBNUtils.clean(isbn)

        // Endpoint "books" avec jscmd=data : renvoie directement noms d'auteurs
        // et éditeurs, contrairement à l'endpoint /isbn/ qui ne donne que des clés.
        var components = URLComponents(string: "https://openlibrary.org/api/books")!
        components.queryItems = [
            URLQueryItem(name: "bibkeys", value: "ISBN:\(cleaned)"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "jscmd", value: "data")
        ]

        guard let url = components.url else { return nil }

        let (data, _) = try await session.data(from: url)
        let decoded = try JSONDecoder().decode([String: BookData].self, from: data)

        guard let book = decoded["ISBN:\(cleaned)"] else { return nil }

        return BookMetadata(
            isbn: cleaned,
            title: book.title ?? "Titre inconnu",
            author: book.authors?.compactMap { $0.name }.joined(separator: ", ") ?? "Auteur inconnu",
            publisher: book.publishers?.first?.name ?? "",
            year: String(book.publish_date?.suffix(4) ?? ""),
            coverURLString: book.cover?.large,
            source: .openLibrary
        )
    }
}
