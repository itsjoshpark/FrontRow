//
//  ContentView.swift
//  Front Row
//
//  Created by Joshua Park on 3/4/24.
//

import SwiftUI

struct ContentView: View {
    @Environment(PlayEngine.self) private var playEngine: PlayEngine
    @Environment(WindowController.self) private var windowController: WindowController
    @State private var chrome = PlayerChromeVisibility()

    var body: some View {
        ZStack(alignment: .bottom) {
            PlayerView(player: playEngine.player)
                .mediaFileDropDestination()
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
                    case .active: chrome.controlsHoverChanged(isInside: true)
                    case .ended: chrome.controlsHoverChanged(isInside: false)
                    }
                }
                .animation(.linear(duration: 0.4), value: chrome.areControlsVisible)
                .opacity(chrome.areControlsVisible ? 1.0 : 0.0)
        }
        .background {
            Color.black.ignoresSafeArea()
        }
        .unopenableRecentFileAlert(in: .player)
        .mediaConversionPresentation(in: .player)
        .onAppear {
            chrome.mouseMoved()
        }
        .onContinuousHover { phase in
            switch phase {
            case .active: chrome.windowHoverChanged(isInside: true)
            case .ended: chrome.windowHoverChanged(isInside: false)
            }
        }
        .onChange(of: windowController.isMouseInTitleBar) { _, isInTitleBar in
            chrome.titleBarHoverChanged(isInside: isInTitleBar)
        }
        // The titlebar fades with the controls: they are one piece of chrome as far as the user
        // is concerned, and it lives in AppKit rather than in this hierarchy.
        .onChange(of: chrome.areControlsVisible) { _, areVisible in
            if areVisible {
                windowController.showTitlebar()
            } else {
                windowController.hideTitlebar()
            }
        }
        .onChange(of: chrome.isCursorHidden) { _, isHidden in
            if isHidden {
                windowController.hideCursor()
            } else {
                windowController.showCursor()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(PlayEngine.shared)
        .environment(PresentedViewManager.shared)
        .environment(WindowController.shared)
}
