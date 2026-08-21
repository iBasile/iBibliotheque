import Foundation

enum BnFError: Error {
    case invalidURL
    case notFound
}

/// Parseur XML minimal pour le format Dublin Core renvoyé par l'API SRU de la BnF.
/// Ne conserve que les champs de la première notice retournée (la plus pertinente).
private final class BnFXMLParser: NSObject, XMLParserDelegate {
    struct Record {
        var title: String?
        var creator: String?
        var publisher: String?
        var date: String?
    }

    private var currentElement = ""
    private var currentText = ""
    private(set) var numberOfRecords = 0
    private(set) var record = Record()

    func parse(data: Data) -> Record? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return numberOfRecords > 0 ? record : nil
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        currentText = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        switch elementName {
        case "srw:numberOfRecords":
            numberOfRecords = Int(text) ?? 0
        case "dc:title":
            if record.title == nil { record.title = text }
        case "dc:creator":
            if record.creator == nil { record.creator = text }
        case "dc:publisher":
            if record.publisher == nil { record.publisher = text }
        case "dc:date":
            if record.date == nil { record.date = text }
        default:
            break
        }
    }
}

/// Client pour l'API SRU du catalogue général de la BnF.
/// Alimentée par le dépôt légal : c'est la source la plus exhaustive pour tout livre
/// publié et diffusé en France.
final class BnFClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func lookup(isbn: String) async throws -> BookMetadata {
        let cleaned = ISBNUtils.clean(isbn)

        // bib.fuzzyIsbn gère les correspondances ISBN10/ISBN13/EAN,
        // notamment pour les éditions antérieures à l'adoption de l'ISBN-13 (2007).
        if let record = try await query(index: "bib.fuzzyIsbn", value: cleaned) {
            return record
        }
        if let record = try await query(index: "bib.isbn", value: cleaned) {
            return record
        }
        // Dernier recours : si l'ISBN scanné est un ISBN-13, tenter son équivalent ISBN-10.
        if cleaned.count == 13, let isbn10 = ISBNUtils.isbn13ToIsbn10(cleaned) {
            if let record = try await query(index: "bib.fuzzyIsbn", value: isbn10) {
                return record
            }
        }

        throw BnFError.notFound
    }

    private func query(index: String, value: String) async throws -> BookMetadata? {
        var components = URLComponents(string: "https://catalogue.bnf.fr/api/SRU")!
        components.queryItems = [
            URLQueryItem(name: "version", value: "1.2"),
            URLQueryItem(name: "operation", value: "searchRetrieve"),
            URLQueryItem(name: "query", value: "\(index) all \"\(value)\""),
            URLQueryItem(name: "recordSchema", value: "dublincore")
        ]

        guard let url = components.url else { throw BnFError.invalidURL }

        let (data, _) = try await session.data(from: url)
        let parser = BnFXMLParser()
        guard let record = parser.parse(data: data) else { return nil }

        return BookMetadata(
            isbn: value,
            title: record.title ?? "Titre inconnu",
            author: cleanAuthor(record.creator),
            publisher: record.publisher ?? "",
            year: extractYear(record.date),
            coverURLString: await coverURL(isbn: value),
            source: .bnf
        )
    }

    // MARK: - Couvertures (API Couvertures du Catalogue général)

    /// Construit l'URL de couverture BnF pour un ISBN donné et vérifie qu'elle existe réellement
    /// (une notice sans image de couverture renvoie une erreur 500 côté API).
    /// Retourne `nil` si aucune couverture n'est disponible, pour laisser BookLookupService
    /// enrichir via Google Books.
    private func coverURL(isbn: String) async -> String? {
        guard let url = buildCoverURL(isbn: isbn, size: .resized(width: 500)) else { return nil }
        guard await coverExists(at: url) else { return nil }
        return url.absoluteString
    }

    private enum CoverSize {
        case thumbnail
        case original
        case resized(width: Int)
    }

    private func buildCoverURL(isbn: String, size: CoverSize, face: Int = 1) -> URL? {
        var components = URLComponents(string: "https://openapi.bnf.fr/couverture/image/image/recupererImage")
        var queryItems = [
            URLQueryItem(name: "ISBN", value: isbn),
            URLQueryItem(name: "couverture", value: String(face)) // 1 = première de couverture
        ]

        switch size {
        case .thumbnail:
            break // paramètre "couverture" seul = miniature
        case .original:
            queryItems.append(URLQueryItem(name: "taille", value: "originale"))
        case .resized(let width):
            queryItems.append(URLQueryItem(name: "taille", value: "originale"))
            queryItems.append(URLQueryItem(name: "largeur", value: String(width)))
        }

        components?.queryItems = queryItems
        return components?.url
    }

    /// Requête HEAD légère : l'API renvoie une erreur 500 si la notice n'a pas de couverture,
    /// ce qui n'est pas une indisponibilité du service mais l'absence de l'image elle-même.
    private func coverExists(at url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }

    /// La BnF formate les auteurs ainsi : "Nom, Prénom (dates). Fonction"
    /// On ne garde que la partie avant le premier point.
    private func cleanAuthor(_ raw: String?) -> String {
        guard let raw else { return "Auteur inconnu" }
        return raw.components(separatedBy: ".").first?.trimmingCharacters(in: .whitespaces) ?? raw
    }

    private func extractYear(_ raw: String?) -> String {
        guard let raw else { return "" }
        return String(raw.prefix(4))
    }
}
