import SwiftUI

private extension ActivityStyle {
    init(snapshot: FriendActivitySnapshot) {
        self.init()
        backgroundHex = snapshot.backgroundHex
        backgroundMode = BackgroundMode(rawValue: snapshot.backgroundMode) ?? .plain
        gradientStartHex = snapshot.gradientStartHex
        gradientEndHex = snapshot.gradientEndHex
        gradientKind = GradientKind(rawValue: snapshot.gradientKind) ?? .linear
        gradientAngle = snapshot.gradientAngle
        gradientCenterX = snapshot.gradientCenterX
        gradientCenterY = snapshot.gradientCenterY
        textHex = snapshot.textHex
        font = FontChoice(rawValue: snapshot.font) ?? .rounded
        textSize = snapshot.textSize
        alignment = TextAlignmentChoice(rawValue: snapshot.alignment) ?? .leading
        verticalAlignment = VerticalAlignmentChoice(rawValue: snapshot.verticalAlignment) ?? .center
        borderHex = snapshot.borderHex
        borderWidth = snapshot.borderWidth
        musicLayout = MusicLayout(rawValue: snapshot.musicLayout) ?? .disc
        musicBorderEnabled = snapshot.musicBorderEnabled
        musicBorderHex = snapshot.musicBorderHex
        musicShowsTitle = snapshot.musicShowsTitle
        musicShowsArtist = snapshot.musicShowsArtist
        musicShowsAlbum = snapshot.musicShowsAlbum
    }
}

struct ReceivedFriendPingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let ping: ReceivedFriendPing

    private var style: ActivityStyle { ActivityStyle(snapshot: ping.snapshot) }

    private var noteText: String {
        let trimmed = ping.snapshot.body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Note" : ping.snapshot.body
    }

    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                if ping.snapshot.kind == "music" {
                    musicContent
                } else {
                    Text(noteText)
                        .font(.system(size: style.textSize, weight: .medium, design: style.fontDesign))
                        .multilineTextAlignment(style.textAlignment)
                        .frame(maxWidth: .infinity, alignment: style.contentAlignment)
                        .foregroundStyle(Color(hex: style.textHex))
                        .padding(24)
                        .frame(minHeight: 160, alignment: style.contentAlignment)
                        .activityCardBackground(style: style, kind: .note, cornerRadius: 24)
                }

                if let message = ping.message, !message.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mensaje de @\(ping.fromUsername)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(message)
                            .font(.body)
                    }
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("@\(ping.fromUsername)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var musicContent: some View {
        HStack(spacing: 16) {
            Group {
                if let urlString = ping.snapshot.musicAlbumArtURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.secondary.opacity(0.12)
                    }
                } else {
                    ZStack {
                        Color.secondary.opacity(0.12)
                        Image(systemName: "music.note")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color(hex: style.textHex).opacity(0.55))
                    }
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(style.musicLayout.clipShape)
            .contentShape(.rect)
            .onTapGesture {
                if let urlString = ping.snapshot.musicSpotifyURL, let url = URL(string: urlString) {
                    openURL(url)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(ping.snapshot.musicTitle?.isEmpty == false ? ping.snapshot.musicTitle! : "Music")
                    .font(.system(size: style.textSize * 0.5, weight: .semibold, design: style.fontDesign))
                if let artist = ping.snapshot.musicArtist, !artist.isEmpty {
                    Text(artist)
                        .font(.system(size: style.textSize * 0.38, design: style.fontDesign))
                        .foregroundStyle(Color(hex: style.textHex).opacity(0.7))
                }
                if let album = ping.snapshot.musicAlbum, !album.isEmpty {
                    Text(album)
                        .font(.system(size: style.textSize * 0.32, design: style.fontDesign))
                        .foregroundStyle(Color(hex: style.textHex).opacity(0.5))
                }
            }

            Spacer(minLength: 0)
        }
        .foregroundStyle(Color(hex: style.textHex))
        .padding(20)
        .frame(minHeight: 160, alignment: .topLeading)
        .activityCardBackground(style: style, kind: .music, cornerRadius: 24)

        if let urlString = ping.snapshot.musicSpotifyURL, let url = URL(string: urlString) {
            Button {
                openURL(url)
            } label: {
                Label("Reproducir en Spotify", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
