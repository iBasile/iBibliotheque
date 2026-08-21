import Foundation

/// Client pour l'API publique Google Books.
/// Utilisé en fallback, et pour enrichir les notices BnF avec une couverture.
final class GoogleBooksClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private struct Response: Codable {
        let items: [Item]?

        struct Item: Codable {
            let volumeInfo: VolumeInfo
        }

        struct VolumeInfo: Codable {
            let title: String?
            let authors: [String]?
            let publisher: String?
            let publishedDate: String?
            let imageLinks: ImageLinks?
        }

        struct ImageLinks: Codable {
            let thumbnail: String?
        }
    }

    func lookup(isbn: String) async throws -> BookMetadata? {
        let cleaned = ISBNUtils.clean(isbn)

        var components = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")!
        components.queryItems = [URLQueryItem(name: "q", value: "isbn:\(cleaned)")]

        guard let url = components.url else { return nil }

        let (data, _) = try await session.data(from: url)
        let decoded = try JSONDecoder().decode(Response.self, from: data)

        guard let item = decoded.items?.first else { return nil }
        let info = item.volumeInfo

        return BookMetadata(
            isbn: cleaned,
            title: info.title ?? "Titre inconnu",
            author: info.authors?.joined(separator: ", ") ?? "Auteur inconnu",
            publisher: info.publisher ?? "",
            year: String(info.publishedDate?.prefix(4) ?? ""),
            coverURLString: info.imageLinks?.thumbnail?.replacingOccurrences(of: "http://", with: "https://"),
            source: .googleBooks
        )
    }
}
