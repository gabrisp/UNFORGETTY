import SwiftUI

/// The real Spotify mark — "spotify-icon" in Assets.xcassets.
struct SpotifyMark: View {
    static let brandColor = Color(red: 0.114, green: 0.725, blue: 0.329)

    var body: some View {
        Image("spotify-icon")
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

struct SpotifySignInButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                SpotifyMark()
                    .frame(width: 28, height: 28)
                Text("Sign in with Spotify")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.glassProminent)
        .tint(SpotifyMark.brandColor)
    }
}
