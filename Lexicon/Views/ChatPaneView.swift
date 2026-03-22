import SwiftUI

struct ChatPaneView: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 10) {
            header

            if let error = viewModel.errorMessage, !error.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.white, Theme.accent)
                    Text(error)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                }
                .padding(10)
                .background(Theme.surfaceStrong)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.accent.opacity(0.35), lineWidth: 1)
                )
                .padding(.horizontal, 20)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if viewModel.messages.isEmpty {
                            emptyState
                                .padding(.top, 60)
                        } else {
                            ForEach(viewModel.messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: viewModel.messages.last?.content ?? "") { _, _ in
                    guard viewModel.messages.last?.isStreaming == true else { return }
                    scrollToBottom(proxy, animated: false)
                }
                .background(Theme.background)
            }

            ComposerView(
                settings: viewModel.settings,
                text: $viewModel.draftText,
                images: viewModel.draftImages,
                isSending: viewModel.isSending,
                onPickImage: viewModel.openImagePicker,
                onRemoveImage: viewModel.removeDraftImage,
                onSend: viewModel.sendCurrentMessage,
                onCancel: viewModel.cancelCurrentRequest
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(Theme.background)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.currentSessionTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            if viewModel.isSending {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Theme.accent)
                    Text(L10n.text("common.live"))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.accent)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Theme.border, lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
                .allowsHitTesting(false)
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Theme.accent)
            Text(greetingText)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
        }
    }

    private var greetingText: String {
        let trimmed = viewModel.settings.username.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return L10n.text("chat.empty.greeting_default")
        }
        return L10n.format("chat.empty.greeting_named", trimmed)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        guard let lastID = viewModel.messages.last?.id else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.16)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastID, anchor: .bottom)
        }
    }
}
