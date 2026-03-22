import SwiftUI

struct SessionListView: View {
    @ObservedObject var viewModel: ChatViewModel

    @State private var isRenameDialogPresented = false
    @State private var renameDraft = ""
    @State private var sessionDeleteTarget: ChatSession?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            newChatButton

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.sessions) { session in
                        SessionRowView(
                            session: session,
                            isSelected: session.id == viewModel.selectedSessionID,
                            onTap: { viewModel.selectSession(session.id) },
                            onDelete: { sessionDeleteTarget = session },
                            onRename: {
                                viewModel.selectSession(session.id)
                                presentRenameDialog(defaultTitle: session.title)
                            }
                        )
                    }
                }
            }

            footerActions
        }
        .padding(12)
        .background(Theme.background)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Theme.border)
                .frame(width: 1)
                .allowsHitTesting(false)
        }
        .alert(L10n.text("session.alert.rename.title"), isPresented: $isRenameDialogPresented) {
            TextField(L10n.text("session.alert.rename.placeholder"), text: $renameDraft)
            Button(L10n.text("common.cancel"), role: .cancel) {}
            Button(L10n.text("common.save")) {
                viewModel.renameCurrentSession(renameDraft)
            }
        } message: {
            Text(L10n.text("session.alert.rename.message"))
        }
        .alert(
            L10n.text("session.alert.delete.title"),
            isPresented: Binding(
                get: { sessionDeleteTarget != nil },
                set: { isPresented in
                    if !isPresented {
                        sessionDeleteTarget = nil
                    }
                }
            )
        ) {
            Button(L10n.text("common.cancel"), role: .cancel) {
                sessionDeleteTarget = nil
            }
            Button(L10n.text("common.delete"), role: .destructive) {
                if let id = sessionDeleteTarget?.id {
                    viewModel.deleteSession(id)
                }
                sessionDeleteTarget = nil
            }
        } message: {
            Text(
                L10n.format(
                    "session.alert.delete.message",
                    sessionDeleteTarget?.title ?? L10n.text("session.default_title")
                )
            )
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Lexicon")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(L10n.text("session.title"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
    }

    private var newChatButton: some View {
        Button {
            viewModel.createSession()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text(L10n.text("session.button.new_chat"))
                Spacer()
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(L10n.text("session.help.new"))
    }

    private var footerActions: some View {
        HStack(spacing: 8) {
            Button(L10n.text("common.rename")) {
                presentRenameDialog(defaultTitle: viewModel.currentSessionTitle)
            }
            .buttonStyle(.plain)
            .modifier(SidebarActionButtonStyle(background: Theme.surfaceStrong, foreground: Theme.textPrimary))

            Button(L10n.text("common.delete")) {
                sessionDeleteTarget = currentSession
            }
            .buttonStyle(.plain)
            .modifier(SidebarActionButtonStyle(background: Theme.surfaceStrong, foreground: Theme.textPrimary))
        }
    }

    private func presentRenameDialog(defaultTitle: String) {
        renameDraft = defaultTitle
        isRenameDialogPresented = true
    }

    private var currentSession: ChatSession? {
        guard let selectedID = viewModel.selectedSessionID else {
            return viewModel.sessions.first
        }
        return viewModel.sessions.first(where: { $0.id == selectedID }) ?? viewModel.sessions.first
    }
}

private struct SessionRowView: View {
    let session: ChatSession
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onRename: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Text(session.previewText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)

                Text(Self.timeFormatter.string(from: session.updatedAt))
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary.opacity(0.8))
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain)
            .modifier(SidebarCircleButtonStyle(background: Theme.surfaceStrong, foreground: Theme.textSecondary))
            .opacity(isSelected ? 1 : 0.5)
        }
        .padding(10)
        .background(isSelected ? Theme.surfaceElevated : Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Theme.accent.opacity(0.5) : Theme.border, lineWidth: 1)
                .allowsHitTesting(false)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button(L10n.text("common.rename"), action: onRename)
            Button(L10n.text("common.delete"), role: .destructive, action: onDelete)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
}

private struct SidebarActionButtonStyle: ViewModifier {
    let background: Color
    let foreground: Color

    func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
                    .allowsHitTesting(false)
            )
    }
}

private struct SidebarCircleButtonStyle: ViewModifier {
    let background: Color
    let foreground: Color

    func body(content: Content) -> some View {
        content
            .foregroundStyle(foreground)
            .frame(width: 26, height: 26)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
                    .allowsHitTesting(false)
            )
    }
}
