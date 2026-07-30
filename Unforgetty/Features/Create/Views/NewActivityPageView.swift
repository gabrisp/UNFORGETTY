import SwiftUI

struct NewActivityPageView: View {
    @ObservedObject var viewModel: CreateActivityViewModel
    @Binding var progress: CGFloat
    let bottomInset: CGFloat
    let isEditing: Bool
    let isVisible: Bool
    @Binding var visibleContentHeight: CGFloat
    @State private var measuredContentHeight: CGFloat = 0

    var body: some View {
        contentLayout
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.snappy, value: bottomInset)
        .toolbarVisibility(.hidden, for: .tabBar)
        .onAppear {
            progress = 0
            updateVisibleContentHeight(measuredContentHeight)
        }
        .onChange(of: isVisible) {
            updateVisibleContentHeight(measuredContentHeight)
        }
        .alert("No se pudo iniciar", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.clearError() } })) { Button("Aceptar", role: .cancel) {} } message: { Text(viewModel.errorMessage ?? "") }
    }

    private var contentLayout: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            measuredPreview

            if isEditing {
                Spacer(minLength: 0)
            } else {
                Color.clear
                    .frame(height: 18)
                    .accessibilityHidden(true)
            }

            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .accessibilityHidden(true)

            if isEditing {
                Color.clear
                    .frame(height: max(0, bottomInset - 44))
                    .accessibilityHidden(true)
            }

            if !isEditing {
                Spacer(minLength: 0)
            }
        }
    }

    private var measuredPreview: some View {
        LivePreviewView(viewModel: viewModel) { newValue in
            measuredContentHeight = newValue
            updateVisibleContentHeight(newValue)
        }
    }

    private func updateVisibleContentHeight(_ newValue: CGFloat) {
        guard isVisible, newValue > 0 else { return }
        withAnimation(.snappy) {
            visibleContentHeight = newValue
        }
    }
}
