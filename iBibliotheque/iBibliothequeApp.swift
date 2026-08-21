//
//  iBibliothequeApp.swift
//  iBibliotheque
//
//  Created by Basile BARGIBANT on 21/08/2026.
//

import SwiftUI
import SwiftData

@main
struct BibliothequeApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                MainLibraryView()
                    .tabItem { Label("Bibliothèque", systemImage: "books.vertical") }
                ScanFlowView()
                    .tabItem { Label("Scanner", systemImage: "barcode.viewfinder") }
            }
        }
        .modelContainer(for: [Furniture.self, Shelf.self, Book.self])
    }
}
