import SwiftUI
import SafariServices

/// Thin wrapper so Safari's own rendering engine can be shown as an in-app sheet instead of
/// leaving the app — used for Terms/Privacy, which need to open "as a sheet," not via `Link`
/// (which hands off to the standalone Safari app).
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

/// A button that opens `url` as an in-app Safari sheet — shared by Settings' Application section
/// and the paywall's Terms/Privacy footer links, so both present the same way instead of one
/// leaving the app via `Link` and the other not.
struct LegalDocumentButton<Label: View>: View {
    let url: URL
    @ViewBuilder var label: () -> Label
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPresented) {
            SafariView(url: url)
                .ignoresSafeArea()
        }
    }
}
