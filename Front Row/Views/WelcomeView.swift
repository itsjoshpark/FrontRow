//
//  WelcomeView.swift
//  Front Row
//
//  Created by Joshua Park on 7/17/26.
//

import SwiftUI

struct WelcomeView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(PresentedViewManager.self) private var presentedViewManager: PresentedViewManager
    @State private var recentDocumentsStore = RecentDocumentsStore.shared

    private var mostRecentDocument: RecentDocument? {
        recentDocumentsStore.documents.first
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    var body: some View {
        @Bindable var presentedViewManager = presentedViewManager

        HStack(spacing: 0) {
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .frame(width: 72, height: 72)

                    VStack(alignment: .leading) {
                        Text("Front Row")
                            .font(.system(size: 20, weight: .bold))

                        Text("Version \(appVersion)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 8) {
                    WelcomeActionRow {
                        Image(systemName: "folder")
                    } title: {
                        Text("Open File...")
                    } action: {
                        Task {
                            await showOpenFileDialog()
                        }
                    }

                    WelcomeActionRow {
                        Image(systemName: "link")
                    } title: {
                        Text("Open URL...")
                    } action: {
                        presentedViewManager.isPresentingOpenURLView.toggle()
                    }

                    if let mostRecentDocument {
                        WelcomeActionRow {
                            Image(systemName: "play.circle")
                        } title: {
                            Text(
                                "Resume \(mostRecentDocument.url.lastPathComponent)",
                                comment:
                                    "Welcome window button to resume the most recently played file"
                            )
                        } action: {
                            Task {
                                await openRecentDocumentAndPresent(id: mostRecentDocument.id)
                            }
                        }
                        .help(mostRecentDocument.url.lastPathComponent)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(width: 280)
            .frame(maxHeight: .infinity)
            .background(Color.black.opacity(0.25))

            recentFilesList
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 640, height: 340)
        .background(.regularMaterial)
        .background(
            WindowAccessor { window in
                window.isMovableByWindowBackground = true
                window.isOpaque = false
                window.backgroundColor = .clear
            }
        )
        .mediaFileDropDestination()
        .sheet(isPresented: $presentedViewManager.isPresentingOpenURLView) {
            OpenURLView()
                .frame(minWidth: 600)
        }
        .alert(
            "Couldn't Open File",
            isPresented: $presentedViewManager.isPresentingBrokenRecentFileAlert
        ) {
            Button("OK") {}
        } message: {
            Text(
                "\"\(presentedViewManager.brokenRecentFileName ?? "")\" could not be found and has been removed from your recent files.",
                comment: "Alert message shown when a recent file can no longer be opened"
            )
        }
        .task {
            WelcomeWindowCoordinator.shared.openMainWindow = { openWindow(id: WindowID.main) }
            WelcomeWindowCoordinator.shared.dismissWelcomeWindow = {
                dismissWindow(id: WindowID.welcome)
            }
        }
    }

    @ViewBuilder
    private var recentFilesList: some View {
        if recentDocumentsStore.documents.isEmpty {
            VStack {
                Spacer()
                Text(
                    "No Recent Files", comment: "Placeholder shown when there are no recent files"
                )
                .foregroundStyle(.secondary)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(recentDocumentsStore.documents) { document in
                        RecentFileRow(url: document.url) {
                            Task {
                                await openRecentDocumentAndPresent(id: document.id)
                            }
                        }
                        .contextMenu {
                            Button(
                                "Remove from Recents",
                                action: {
                                    recentDocumentsStore.remove(document.id)
                                }
                            )
                        }
                    }
                }
                .padding(12)
            }
            .ignoresSafeArea(.container, edges: .top)
        }
    }

    @MainActor
    private func showOpenFileDialog() async {
        guard let url = await presentOpenFilePanel() else { return }
        await openFileAndPresent(url: url)
    }
}

private struct WelcomeActionRow<Icon: View, Title: View>: View {
    let icon: Icon
    let title: Title
    let action: () -> Void

    @State private var isHovering = false

    init(
        @ViewBuilder icon: () -> Icon, @ViewBuilder title: () -> Title,
        action: @escaping () -> Void
    ) {
        self.icon = icon()
        self.title = title()
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                icon
                    .frame(width: 20)
                title
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(isHovering ? 0.14 : 0.08))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

private struct RecentFileRow: View {
    let url: URL
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(nsImage: url.recentDocumentIcon)
                    .resizable()
                    .frame(width: 32, height: 32)

                Text(url.lastPathComponent)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(isHovering ? 0.08 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(url.lastPathComponent)
    }
}

#Preview {
    WelcomeView()
        .environment(PresentedViewManager.shared)
}
