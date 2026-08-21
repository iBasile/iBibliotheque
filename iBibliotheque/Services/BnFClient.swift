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
            coverURLString: nil, // la BnF ne fournit pas de couverture via cet endpoint
            source: .bnf
        )
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
