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

                            Task {
                                guard let url = await provider.getURL() else { return }
                                guard await PlayEngine.shared.openFile(url: url) else { return }
                                NSDocumentController.shared.noteNewRecentDocumentURL(url)
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
                .animation(.linear(duration: 0.4), value: playerControlsShown)
                .opacity(playerControlsShown ? 1.0 : 0.0)
        }
        .background {
            Color.black.ignoresSafeArea()
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
                hidePlayerControls()
                WindowController.shared.hideTitlebar()
                WindowController.shared.showCursor()
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

        mouseIdleTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) {
            mouseIdleTimerAction($0)
        }
    }

    private func mouseIdleTimerAction(_ sender: Timer) {
        hidePlayerControls()
        WindowController.shared.hideTitlebar()
        if mouseInsideWindow {
            WindowController.shared.hideCursor()
        }
    }
}

#Preview {
    ContentView()
}
