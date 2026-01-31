//
//  ContentView.swift
//  Front Row
//
//  Created by Joshua Park on 3/4/24.
//

import SwiftUI

struct ContentView: View {
    @Environment(PlayEngine.self) var playEngine: PlayEngine
    @State private var mouseIdleTimer: Timer!
    @State private var mouseInsideWindow = false
    @State private var playerControlsShown = true

    var body: some View {
        @Bindable var playEngine = playEngine

        ZStack(alignment: .bottom) {
            PlayerView(player: PlayEngine.shared.player)
                .onDrop(
                    of: [.fileURL],
                    delegate: AnyDropDelegate(
                        onValidate: {
                            $0.hasItemsConforming(to: PlayEngine.supportedFileTypes)
                        },
                        onPerform: {
                            guard let provider = $0.itemProviders(for: [.fileURL]).first else {
                                return false
                            }

                            provider.loadFileURL { url in
                                guard let url else { return }
                                Task { @MainActor in
                                    guard await PlayEngine.shared.openFile(url: url) else { return }
                                    NSDocumentController.shared.noteNewRecentDocumentURL(url)
                                }
                            }

                            return true
                        }
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .ignoresSafeArea()

            if !playEngine.isLocalFile
                && playEngine.timeControlStatus == .waitingToPlayAtSpecifiedRate
            {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }

            PlayerControlsView()
                .onContinuousHover { phase in
                    switch phase {
                    case .active:
                        WindowController.shared.isMouseInPlayerControls = true
                        resetMouseIdleTimer()
                        showPlayerControls()
                        WindowController.shared.showTitlebar()
                        WindowController.shared.showCursor()
                    case .ended:
                        WindowController.shared.isMouseInPlayerControls = false
                    }
                }
                .animation(.linear(duration: 0.4), value: playerControlsShown)
                .opacity(playerControlsShown ? 1.0 : 0.0)
        }
        .background {
            Color.black.ignoresSafeArea()
        }
        .onAppear {
            resetMouseIdleTimer()
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                mouseInsideWindow = true
                resetMouseIdleTimer()
                showPlayerControls()
                WindowController.shared.showTitlebar()
                WindowController.shared.showCursor()
            case .ended:
                mouseInsideWindow = false
                // Only hide if mouse is not hovering over title bar or controls
                let isHoveringInteractiveArea =
                    WindowController.shared.isMouseInTitleBar
                    || WindowController.shared.isMouseInPlayerControls
                if !isHoveringInteractiveArea {
                    hidePlayerControls()
                    WindowController.shared.hideTitlebar()
                }
                WindowController.shared.showCursor()
            }
        }
        .onChange(of: WindowController.shared.isMouseInTitleBar) { _, isInTitleBar in
            if isInTitleBar {
                // When mouse enters title bar, show controls and reset idle timer
                showPlayerControls()
                WindowController.shared.showTitlebar()
                resetMouseIdleTimer()
            } else if !mouseInsideWindow && !WindowController.shared.isMouseInPlayerControls {
                // When mouse leaves title bar and is not in content area or controls, hide UI
                hidePlayerControls()
                WindowController.shared.hideTitlebar()
            }
        }
    }

    private func hidePlayerControls() {
        withAnimation {
            playerControlsShown = false
        }
    }

    private func showPlayerControls() {
        withAnimation {
            playerControlsShown = true
        }
    }

    private func resetMouseIdleTimer() {
        if mouseIdleTimer != nil {
            mouseIdleTimer.invalidate()
            mouseIdleTimer = nil
        }

        mouseIdleTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            MainActor.assumeIsolated {
                self.mouseIdleTimerAction()
            }
        }
    }

    private func mouseIdleTimerAction() {
        let isHoveringInteractiveArea =
            WindowController.shared.isMouseInTitleBar
            || WindowController.shared.isMouseInPlayerControls

        // Only hide controls if mouse is not hovering over title bar or controls
        if !isHoveringInteractiveArea {
            hidePlayerControls()
            WindowController.shared.hideTitlebar()
        }
        // Only hide cursor if mouse is in content area (not title bar or controls)
        if mouseInsideWindow && !isHoveringInteractiveArea {
            WindowController.shared.hideCursor()
        }
    }
}

#Preview {
    ContentView()
        .environment(PlayEngine.shared)
        .environment(PresentedViewManager.shared)
        .environment(WindowController.shared)
}
