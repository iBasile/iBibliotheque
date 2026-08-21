import Foundation
import SwiftData

/// Représente une étagère au sein d'un meuble.
/// `number` est numéroté en partant du haut (1 = étagère la plus haute).
@Model
final class Shelf {
    var id: UUID
    var number: Int
    var furniture: Furniture?

    @Relationship(deleteRule: .cascade, inverse: \Book.shelf)
    var books: [Book] = []

    init(number: Int, furniture: Furniture? = nil) {
        self.id = UUID()
        self.number = number
        self.furniture = furniture
    }
}
