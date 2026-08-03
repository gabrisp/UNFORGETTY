import SwiftUI

/// Step 2 of the friend-send flow, reached from FriendPickerSheet's confirm button — the message
/// (optional) and the send button's color, for whoever was just selected. Tapping the checkmark
/// here finalizes the compose step (closes back to the editor; the actual send still happens from
/// the main screen's own send button). Reopening the friend picker later and stepping through
/// again shows whatever was set here, ready to edit.
struct FriendMessageComposeSheet: View {
    @ObservedObject var viewModel: CreateActivityV2EditViewModel
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 18) {
                    recipientsSection

                    editorSection("Mensaje (opcional)") {
                        TextField("Escribe algo…", text: $viewModel.friendMessage, axis: .vertical)
                            .lineLimit(1...4)
                    }

                    editorSection("Botón de enviar") {
                        ColorPicker("Color", selection: viewModel.hexBinding(\.friendSendButtonColorHex), supportsOpacity: false)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Mensaje")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: onDone) {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
        .foregroundStyle(.white)
        .tint(.yellow)
        .preferredColorScheme(.dark)
    }

    private var recipientsSection: some View {
        editorSection("Para") {
            Text(viewModel.sendToFriendUsernames.map { "@\($0)" }.joined(separator: ", "))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private func editorSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
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
}
