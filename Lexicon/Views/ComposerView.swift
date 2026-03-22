import SwiftUI

struct ComposerView: View {
    @ObservedObject var settings: SettingsStore
    @Binding var text: String
    let images: [ImageAttachment]
    let isSending: Bool
    let onPickImage: () -> Void
    let onRemoveImage: (ImageAttachment) -> Void
    let onSend: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(images) { image in
                            ZStack(alignment: .topTrailing) {
                                Image(nsImage: image.preview)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 94, height: 70)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Theme.border, lineWidth: 1)
                                            .allowsHitTesting(false)
                                    )

                                Button {
                                    onRemoveImage(image)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.white, Theme.accent)
                                        .padding(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            ZStack(alignment: .topLeading) {
                ReturnSendTextEditor(text: $text) {
                    guard !isSending else { return }
                    onSend()
                }
                .frame(minHeight: 84, maxHeight: 150)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.surfaceStrong)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                        .allowsHitTesting(false)
                )

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(L10n.text("composer.placeholder"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.leading, 16)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }
            }

            HStack(spacing: 10) {
                Button(action: onPickImage) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle")
                        Text(L10n.text("composer.button.image"))
                    }
                    .frame(height: 34)
                    .padding(.horizontal, 12)
                    .background(Theme.surfaceStrong)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                            .allowsHitTesting(false)
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textPrimary)

                Spacer()

                modelSwitcher

                if isSending {
                    Button(action: onCancel) {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.fill")
                            Text(L10n.text("composer.button.stop"))
                                .fontWeight(.semibold)
                        }
                        .frame(height: 34)
                        .padding(.horizontal, 16)
                        .background(Theme.surfaceStrong)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.textPrimary)
                } else {
                    Button(action: onSend) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up")
                            Text(L10n.text("composer.button.send"))
                                .fontWeight(.semibold)
                        }
                        .frame(height: 34)
                        .padding(.horizontal, 16)
                        .background(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                }
            }
        }
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
                .allowsHitTesting(false)
        )
    }

    private var modelSwitcher: some View {
        Menu {
            if settings.availableModelOptions.isEmpty {
                Text(L10n.text("composer.model.none"))
            } else {
                ForEach(settings.availableModelOptions) { option in
                    Button {
                        settings.selectActiveModel(providerID: option.providerID, modelID: option.modelID)
                    } label: {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(option.modelName)
                                Text(option.providerName)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            if option.providerID == settings.activeProviderID && option.modelID == settings.activeModelID {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                Text(currentModelLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(height: 34)
            .padding(.horizontal, 12)
            .background(Theme.surfaceStrong)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
                    .allowsHitTesting(false)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: 280)
    }

    private var currentModelLabel: String {
        guard let active = settings.activeModelOption else {
            return L10n.text("composer.model.none")
        }
        return "\(active.providerName) · \(active.modelName)"
    }
}
