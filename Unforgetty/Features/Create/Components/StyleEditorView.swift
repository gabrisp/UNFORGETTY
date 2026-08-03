import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct StyleEditorView<VM: DraftEditingViewModel>: View {
    @ObservedObject var viewModel: VM
    var onUpdate: () -> Void = {}
    @State private var backgroundImageSelection: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.draft.kind == .music {
                personalizationGroup {
                    Picker("Art position", selection: $viewModel.draft.style.musicArtPosition) {
                        Label("Left", systemImage: "align.horizontal.left").tag(ActivityStyle.MusicArtPosition.leading)
                        Label("Right", systemImage: "align.horizontal.right").tag(ActivityStyle.MusicArtPosition.trailing)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)

                    musicLayoutPicker
                        .padding(.top, 2)

                    Toggle("Border", isOn: $viewModel.draft.style.musicBorderEnabled)
                        .padding(.top, 2)

                    if viewModel.draft.style.musicBorderEnabled {
                        settingsRow("Color del borde") {
                            ColorPicker("Color del borde", selection: viewModel.hexBinding(\.musicBorderHex))
                                .labelsHidden()
                        }
                    }

                    Toggle("Título", isOn: $viewModel.draft.style.musicShowsTitle)
                        .padding(.top, 2)
                    Toggle("Artista", isOn: $viewModel.draft.style.musicShowsArtist)
                    Toggle("Álbum", isOn: $viewModel.draft.style.musicShowsAlbum)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            personalizationGroup("Background") {
                if viewModel.draft.kind == .image {
                    backgroundImagePicker
                } else {
                    Picker("Background", selection: backgroundModeBinding) {
                        Text("Plain").tag(ActivityStyle.BackgroundMode.plain)
                        Text("Gradient").tag(ActivityStyle.BackgroundMode.gradient)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)

                    switch viewModel.draft.style.backgroundMode {
                    case .plain:
                        settingsRow("Color") {
                            ColorPicker("Color", selection: viewModel.hexBinding(\.backgroundHex))
                                .labelsHidden()
                        }
                    case .gradient:
                        settingsRow("Type") {
                            Picker("Type", selection: $viewModel.draft.style.gradientKind) {
                                ForEach(ActivityStyle.GradientKind.allCases) { kind in
                                    Text(kind.title).tag(kind)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }

                        settingsRow("Start") {
                            ColorPicker("Gradient Start", selection: viewModel.hexBinding(\.gradientStartHex))
                                .labelsHidden()
                        }

                        settingsRow("End") {
                            ColorPicker("Gradient End", selection: viewModel.hexBinding(\.gradientEndHex))
                                .labelsHidden()
                        }

                        labeledSlider("Rotation", value: $viewModel.draft.style.gradientAngle, range: 0...360, suffix: "°")
                        labeledSlider("Horizontal", value: $viewModel.draft.style.gradientCenterX, range: 0...1)
                        labeledSlider("Vertical", value: $viewModel.draft.style.gradientCenterY, range: 0...1)
                    case .image:
                        EmptyView()
                    }
                }
            }
            // Only this section mutates background fields by direct user action — the automatic
            // music-album-art gradient is applied from CreateActivityV2EditViewModel.selectTrack
            // while this view isn't mounted (the song picker is a separate sheet), so there's no
            // risk of these firing for that automatic write and wrongly marking it "customized".
            .onChange(of: viewModel.draft.style.backgroundMode) { viewModel.draft.style.backgroundIsCustomized = true }
            .onChange(of: viewModel.draft.style.backgroundHex) { viewModel.draft.style.backgroundIsCustomized = true }
            .onChange(of: viewModel.draft.style.gradientStartHex) { viewModel.draft.style.backgroundIsCustomized = true }
            .onChange(of: viewModel.draft.style.gradientEndHex) { viewModel.draft.style.backgroundIsCustomized = true }
            .onChange(of: viewModel.draft.style.gradientKind) { viewModel.draft.style.backgroundIsCustomized = true }
            .onChange(of: viewModel.draft.style.gradientAngle) { viewModel.draft.style.backgroundIsCustomized = true }
            .onChange(of: viewModel.draft.style.gradientCenterX) { viewModel.draft.style.backgroundIsCustomized = true }
            .onChange(of: viewModel.draft.style.gradientCenterY) { viewModel.draft.style.backgroundIsCustomized = true }

            personalizationGroup("Border") {
                labeledSlider("Width", value: $viewModel.draft.style.borderWidth, range: 0...8)

                if viewModel.draft.style.borderWidth > 0 {
                    settingsRow("Color") {
                        ColorPicker("Color", selection: viewModel.hexBinding(\.borderHex))
                            .labelsHidden()
                    }
                }
            }

            personalizationGroup("Content") {
                settingsRow("Color") {
                    ColorPicker("Color", selection: viewModel.hexBinding(\.textHex))
                        .labelsHidden()
                }

                Picker("Alignment", selection: $viewModel.draft.style.alignment) {
                    Text("Leading").tag(ActivityStyle.TextAlignmentChoice.leading)
                    Text("Center").tag(ActivityStyle.TextAlignmentChoice.center)
                    Text("Trailing").tag(ActivityStyle.TextAlignmentChoice.trailing)
                }
                .labelsHidden()
                .pickerStyle(.segmented)

                Picker("Vertical", selection: $viewModel.draft.style.verticalAlignment) {
                    Text("Top").tag(ActivityStyle.VerticalAlignmentChoice.top)
                    Text("Center").tag(ActivityStyle.VerticalAlignmentChoice.center)
                    Text("Bottom").tag(ActivityStyle.VerticalAlignmentChoice.bottom)
                }
                .labelsHidden()
                .pickerStyle(.segmented)

                settingsRow("Font") {
                    FontPickerButton(selection: $viewModel.draft.style.font)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text("Size")
                        Spacer()
                        Text("\(Int(textSizeBinding.wrappedValue))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.58))
                    }

                    Slider(value: textSizeBinding, in: ActivityStyle.minimumTextSize...ActivityStyle.maximumTextSize, step: 1)
                }
                .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text("Line spacing")
                        Spacer()
                        Text(String(format: "%.2f", viewModel.draft.style.lineSpacingMultiplier))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.58))
                    }

                    Slider(value: $viewModel.draft.style.lineSpacingMultiplier, in: 0...0.5)
                }
                .padding(.vertical, 2)
            }

            if viewModel.draft.kind == .check(.todoList) {
                personalizationGroup("Scheme") {
                    checklistSchemePicker
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .foregroundStyle(.white)
        .tint(.yellow)
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.draft.style.textSize = textSizeBinding.wrappedValue
            if viewModel.draft.kind != .image, viewModel.draft.style.backgroundMode == .image {
                viewModel.draft.style.backgroundMode = .plain
            }
        }
        .onChange(of: backgroundImageSelection) { _, newValue in
            loadBackgroundImage(newValue)
        }
        .sensoryFeedback(.selection, trigger: viewModel.draft.style.backgroundMode)
        .sensoryFeedback(.selection, trigger: viewModel.draft.style.gradientKind)
        .sensoryFeedback(.selection, trigger: viewModel.draft.style.alignment)
        .sensoryFeedback(.selection, trigger: viewModel.draft.style.verticalAlignment)
        .sensoryFeedback(.selection, trigger: viewModel.draft.style.font)
        .sensoryFeedback(.selection, trigger: viewModel.draft.style.checklistScheme)
        .sensoryFeedback(.selection, trigger: viewModel.draft.style.musicLayout)
        .sensoryFeedback(.selection, trigger: viewModel.draft.style.musicArtPosition)
        .sensoryFeedback(.selection, trigger: viewModel.draft.style.musicBorderEnabled)
        .sensoryFeedback(.selection, trigger: viewModel.draft.style.musicShowsTitle)
        .sensoryFeedback(.selection, trigger: viewModel.draft.style.musicShowsArtist)
        .sensoryFeedback(.selection, trigger: viewModel.draft.style.musicShowsAlbum)
    }

    private var textSizeBinding: Binding<Double> {
        Binding {
            min(ActivityStyle.maximumTextSize, max(ActivityStyle.minimumTextSize, viewModel.draft.style.textSize))
        } set: { newValue in
            viewModel.draft.style.textSize = newValue
        }
    }

    private var backgroundModeBinding: Binding<ActivityStyle.BackgroundMode> {
        Binding {
            if viewModel.draft.kind != .image, viewModel.draft.style.backgroundMode == .image {
                return .plain
            }
            return viewModel.draft.style.backgroundMode
        } set: { newValue in
            viewModel.draft.style.backgroundMode = newValue == .image && viewModel.draft.kind != .image ? .plain : newValue
        }
    }

    private var backgroundImagePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhotosPicker(selection: $backgroundImageSelection, matching: .images) {
                HStack {
                    Text(viewModel.draft.style.backgroundImageData == nil ? "Choose Image" : "Change Image")
                    Spacer()
                    if viewModel.draft.style.backgroundImageData != nil {
                        Image(systemName: "checkmark")
                    }
                }
                .font(.body.weight(.medium))
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if viewModel.draft.style.backgroundImageData != nil {
                Button(role: .destructive) {
                    viewModel.draft.style.backgroundImageData = nil
                    onUpdate()
                } label: {
                    Text("Remove Image")
                }
                .buttonStyle(.plain)

                labeledSlider("Padding", value: $viewModel.draft.style.imageInset, range: 0...40)
            }
        }
    }

    private func loadBackgroundImage(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            await MainActor.run {
                viewModel.draft.style.backgroundImageData = ImagePreparation.preparedBackgroundImageData(from: data)
                onUpdate()
            }
        }
    }

    private func personalizationGroup<Content: View>(_ title: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))
                    .textCase(.uppercase)
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 18, style: .continuous))
    }

    private func settingsRow<Trailing: View>(_ title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.body.weight(.medium))

            Spacer(minLength: 12)

            trailing()
        }
    }

    private func labeledSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String = "") -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(title)
                Spacer()
                Text("\(formattedValue(value.wrappedValue))\(suffix)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))
            }

            Slider(value: value, in: range, step: range.upperBound == 1 ? 0.01 : 1)
        }
        .padding(.vertical, 2)
    }

    private func formattedValue(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.2f", value)
    }

    private var checklistSchemePicker: some View {
        ScrollView(.horizontal) {
            LazyHGrid(
                rows: [
                    GridItem(.fixed(72), spacing: 10),
                    GridItem(.fixed(72), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(ActivityStyle.ChecklistScheme.allCases) { scheme in
                    Button {
                        withAnimation(.snappy) {
                            viewModel.draft.style.checklistScheme = scheme
                        }
                    } label: {
                        VStack {
                            checklistSchemeIcon(scheme)
                                .frame(width: 28, height: 28)
                        }
                        .frame(width: 56, height: 52)
                        .background(scheme == viewModel.draft.style.checklistScheme ? Color.white.opacity(0.18) : Color.white.opacity(0.08), in: .rect(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 154)
        .scrollIndicators(.hidden)
    }

    private var musicLayoutPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(ActivityStyle.MusicLayout.allCases) { layout in
                    Button {
                        withAnimation(.snappy) {
                            viewModel.draft.style.musicLayout = layout
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: musicLayoutIcon(layout))
                                .font(.system(size: 22, weight: .semibold))
                            Text(layout.title)
                                .font(.caption2.weight(.semibold))
                        }
                        .frame(width: 88, height: 64)
                        .background(layout == viewModel.draft.style.musicLayout ? Color.white.opacity(0.18) : Color.white.opacity(0.08), in: .rect(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 88)
        .scrollIndicators(.hidden)
    }

    private func musicLayoutIcon(_ layout: ActivityStyle.MusicLayout) -> String {
        switch layout {
        case .disc: "opticaldisc"
        case .square: "square.fill"
        case .heart: "heart.fill"
        case .diamond: "diamond.fill"
        case .star: "star.fill"
        }
    }

    @ViewBuilder
    private func checklistSchemeIcon(_ scheme: ActivityStyle.ChecklistScheme) -> some View {
        if let symbol = scheme.completedSymbol {
            Image(systemName: symbol)
                .font(.system(size: 24 * scheme.symbolScale, weight: .semibold))
        } else {
            ZStack {
                Circle()
                    .stroke(lineWidth: 2)
                    .frame(width: 28, height: 28)
                if scheme == .circleCheckPadded {
                    Circle()
                        .fill(.white)
                        .frame(width: 15, height: 15)
                        .opacity(0.9)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                }
            }
        }
    }
}
