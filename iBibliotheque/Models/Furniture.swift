import Foundation
import SwiftData

/// Représente un meuble de rangement (bibliothèque, étagère murale, etc.)
@Model
final class Furniture {
    var id: UUID
    var name: String

    @Relationship(deleteRule: .cascade, inverse: \Shelf.furniture)
    var shelves: [Shelf] = []

    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}
