import Foundation

enum ISBNUtils {

    /// Retire tirets, espaces et autres caractères parasites d'un ISBN scanné.
    static func clean(_ raw: String) -> String {
        raw.uppercased().filter { $0.isNumber || $0 == "X" }
    }

    /// Convertit un ISBN-13 (préfixe 978) en ISBN-10.
    /// Utile car certaines notices BnF antérieures à 2007 ne sont cataloguées
    /// que sous leur ISBN-10 d'origine.
    static func isbn13ToIsbn10(_ isbn13: String) -> String? {
        let cleaned = clean(isbn13)
        guard cleaned.count == 13, cleaned.hasPrefix("978") else { return nil }

        let core = Array(cleaned.dropFirst(3).dropLast())
        guard core.count == 9 else { return nil }

        var sum = 0
        for (index, character) in core.enumerated() {
            guard let digit = character.wholeNumberValue else { return nil }
            sum += (10 - index) * digit
        }

        let checkValue = (11 - (sum % 11)) % 11
        let checkCharacter = checkValue == 10 ? "X" : String(checkValue)

        return String(core) + checkCharacter
    }
}
