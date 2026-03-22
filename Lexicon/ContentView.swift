import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SessionListView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
        } detail: {
            ChatPaneView(viewModel: viewModel)
                .frame(minWidth: 680)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .help(L10n.text("content.help.open_settings"))
            }
        }
        .background(Theme.background)
    }
}
