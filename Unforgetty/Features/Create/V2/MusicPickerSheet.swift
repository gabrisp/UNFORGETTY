import SwiftUI

struct MusicPickerSheet: View {
    @EnvironmentObject private var store: ActivityStore
    @ObservedObject var viewModel: CreateActivityV2EditViewModel
    let onDone: () -> Void

    @State private var query = ""
    @State private var results: [SpotifyRepository.SpotifyTrack] = []
    @State private var isSearching = false
    @State private var nowPlaying: SpotifyRepository.SpotifyTrack?
    @State private var isLoadingNowPlaying = false
    @State private var errorMessage: String?
    @State private var isSpotifyConnected = false
    @StateObject private var spotifyAuth = SpotifySettingsModel()

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 24) {
                    TextField("Canción o artista", text: $query)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .frame(minHeight: 46)
                        .background(.white.opacity(0.1), in: .rect(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.white.opacity(0.14), lineWidth: 1)
                        }

                    if !isSpotifyConnected {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Necesitas elegir un servicio")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.58))
                                .textCase(.uppercase)

                            SpotifySignInButton {
                                Task {
                                    Haptics.light()
                                    await spotifyAuth.connect()
                                    isSpotifyConnected = spotifyAuth.isConnected
                                    if isSpotifyConnected {
                                        await loadNowPlaying()
                                    }
                                }
                            }

                            if spotifyAuth.isStatusError, let statusMessage = spotifyAuth.statusMessage {
                                Text(statusMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                    } else if isLoadingNowPlaying {
                        musicSection("Escuchando ahora") {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        }
                    } else if let nowPlaying {
                        musicSection("Escuchando ahora") {
                            trackRow(nowPlaying)
                        }
                    }

                    if isSearching {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if !results.isEmpty {
                        musicSection("Resultados") {
                            ForEach(results) { track in
                                trackRow(track)

                                if track.id != results.last?.id {
                                    Divider().overlay(.white.opacity(0.1))
                                }
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Elegir canción")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onDone()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
        .foregroundStyle(.white)
        .tint(.yellow)
        .preferredColorScheme(.dark)
        .task {
            isSpotifyConnected = (try? await SpotifyRepository.shared.status()) ?? false
            if isSpotifyConnected {
                await loadNowPlaying()
            }
        }
        .task(id: query) {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                results = []
                return
            }
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            isSearching = true
            defer { isSearching = false }
            do {
                results = try await SpotifyRepository.shared.search(query: trimmed)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func musicSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
                .textCase(.uppercase)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 18, style: .continuous))
    }

    private func isSelected(_ track: SpotifyRepository.SpotifyTrack) -> Bool {
        !track.id.isEmpty && track.id == viewModel.draft.musicSpotifyTrackID
    }

    private func trackRow(_ track: SpotifyRepository.SpotifyTrack) -> some View {
        Button {
            Task {
                Haptics.selection()
                await selectTrack(track)
            }
        } label: {
            HStack(spacing: 12) {
                trackArt(track)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                    Text(track.album)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if isSelected(track) {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.yellow)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func trackArt(_ track: SpotifyRepository.SpotifyTrack) -> some View {
        Group {
            if let urlString = track.albumArtURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.white.opacity(0.1)
                }
            } else {
                ZStack {
                    Color.white.opacity(0.1)
                    Image(systemName: "music.note")
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(.rect(cornerRadius: 10, style: .continuous))
        .overlay {
            if isSelected(track) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.yellow, lineWidth: 2)
            }
        }
    }

    private func loadNowPlaying() async {
        isLoadingNowPlaying = true
        defer { isLoadingNowPlaying = false }
        nowPlaying = try? await SpotifyRepository.shared.currentlyPlaying()
    }

    private func selectTrack(_ track: SpotifyRepository.SpotifyTrack) async {
        await viewModel.selectTrack(track)
        viewModel.saveDraft(store: store)
    }
}
