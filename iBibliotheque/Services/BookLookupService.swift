import Foundation

/// Point d'entrée unique pour la recherche de livre par ISBN.
/// Le reste de l'app n'a jamais à savoir d'où vient la donnée.
///
/// Ordre de la cascade :
/// 1. BnF (dépôt légal, exhaustif pour les livres français, couverture via l'API Couvertures
///    quand elle existe dans la notice)
/// 2. Google Books (comble les couvertures manquantes à la BnF, fallback si BnF ne trouve rien)
/// 3. Open Library (dernier recours, notamment pour livres étrangers/traduits)
final class BookLookupService {
    private let bnf = BnFClient()
    private let google = GoogleBooksClient()
    private let openLibrary = OpenLibraryClient()

    func lookup(isbn: String) async -> BookMetadata? {
        do {
            let result = try await bnf.lookup(isbn: isbn)
            // Si la notice BnF n'a pas de couverture (zone 950 absente), on enrichit via Google Books.
            if result.coverURLString == nil {
                do {
                    let googleResult = try await google.lookup(isbn: isbn)
                    if let googleResult, let cover = googleResult.coverURLString {
                        var enriched = result
                        enriched.coverURLString = cover
                        return enriched
                    } else {
                        debugLog("Google Books n'a retourné aucune couverture pour \(isbn) (enrichissement BnF).")
                    }
                } catch {
                    debugLog("Échec Google Books lors de l'enrichissement BnF pour \(isbn) : \(error)")
                }
            }
            return result
        } catch {
            debugLog("Échec BnF pour \(isbn) : \(error)")
        }

        do {
            if let result = try await google.lookup(isbn: isbn) {
                return result
            }
            debugLog("Google Books n'a retourné aucun résultat pour \(isbn).")
        } catch {
            debugLog("Échec Google Books pour \(isbn) : \(error)")
        }

        do {
            if let result = try await openLibrary.lookup(isbn: isbn) {
                return result
            }
            debugLog("Open Library n'a retourné aucun résultat pour \(isbn).")
        } catch {
            debugLog("Échec Open Library pour \(isbn) : \(error)")
        }

        return nil
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("🔍 BookLookupService: \(message)")
        #endif
    }
}
