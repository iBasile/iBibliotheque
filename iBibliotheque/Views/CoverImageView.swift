import SwiftUI

/// Affiche une couverture de livre via AsyncImage, avec un placeholder
/// si l'URL est absente ou si le chargement échoue.
struct CoverImageView: View {
    let urlString: String?

    var body: some View {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                case .failure(let error):
                    placeholder
                        .onAppear {
                            #if DEBUG
                            print("⚠️ CoverImageView: échec de chargement pour \(url) — \(error)")
                            #endif
                        }
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                @unknown default:
                    placeholder
                }
            }
        } else {
            placeholder
                .onAppear {
                    #if DEBUG
                    print("⚠️ CoverImageView: aucune URL de couverture fournie (urlString == nil)")
                    #endif
                }
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.secondary.opacity(0.15))
            .overlay {
                Image(systemName: "book.closed")
                    .foregroundStyle(.secondary)
            }
    }
}
