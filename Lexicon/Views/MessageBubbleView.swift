import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if message.role == .user {
                Spacer(minLength: 40)
                bubble
            } else {
                bubble
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, 20)
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(roleTitle)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(roleColor)

            if !message.images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(message.images) { image in
                            Image(nsImage: image.preview)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 124, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Theme.border, lineWidth: 1)
                                        .allowsHitTesting(false)
                                )
                        }
                    }
                }
            }

            if message.content.isEmpty, message.isStreaming {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Theme.accent)
                    Text(L10n.text("bubble.generating"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            } else {
                MarkdownMessageView(text: message.content.isEmpty ? " " : message.content)
            }
        }
        .padding(14)
        .frame(maxWidth: 620, alignment: .leading)
        .background(bubbleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(roleColor.opacity(0.22), lineWidth: 1)
                .allowsHitTesting(false)
        )
    }

    private var roleTitle: String {
        switch message.role {
        case .assistant:
            return L10n.text("role.assistant")
        case .user:
            return L10n.text("role.user")
        case .system:
            return L10n.text("role.system")
        }
    }

    private var roleColor: Color {
        switch message.role {
        case .assistant:
            return Theme.accent
        case .user:
            return Theme.textSecondary
        case .system:
            return .yellow
        }
    }

    private var bubbleBackground: Color {
        switch message.role {
        case .assistant:
            return Theme.surfaceStrong
        case .user:
            return Theme.surface
        case .system:
            return Theme.surfaceElevated
        }
    }
}
