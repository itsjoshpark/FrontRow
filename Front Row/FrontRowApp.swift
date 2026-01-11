//
//  FrontRowApp.swift
//  Front Row
//
//  Created by Joshua Park on 3/4/24.
//

import AVKit
import Sparkle
import SwiftUI

@main
struct FrontRowApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var playEngine: PlayEngine
    @State private var presentedViewManager: PresentedViewManager
    @State private var windowController: WindowController
    private let updaterController: SPUStandardUpdaterController
    private let keyDownListener = KeyDownListener()

    init() {
        self._playEngine = .init(wrappedValue: .shared)
        self._presentedViewManager = .init(wrappedValue: .shared)
        self._windowController = .init(wrappedValue: .shared)

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        keyDownListener.startMonitoringKeyEvents()

        UserDefaults.standard.set(false, forKey: "NSFullScreenMenuItemEverywhere")
    }

    var body: some Scene {
        Window("Front Row", id: "main") {
            ContentView()
                .preferredColorScheme(.dark)
                .ignoresSafeArea()
                .environment(playEngine)
                .navigationTitle(playEngine.fileURL?.lastPathComponent ?? "Front Row")
                .if(playEngine.isLocalFile) { view in
                    view.navigationDocument(playEngine.fileURL!)
                }
                .sheet(isPresented: $presentedViewManager.isPresentingOpenURLView) {
                    OpenURLView()
                        .frame(minWidth: 600)
                }
                .alert("Go to Time", isPresented: $presentedViewManager.isPresentingGoToTimeView) {
                    GoToTimeView()
                } message: {
                    Text("Enter the time you want to go to")
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSWindow.willEnterFullScreenNotification)
                ) { _ in
                    windowController.showTitlebar(immediately: true)
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSWindow.didEnterFullScreenNotification)
                ) { _ in
                    keyDownListener.stopMonitoringKeyEvents()
                    windowController.setIsFullscreen(true)
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSWindow.didExitFullScreenNotification)
                ) { _ in
                    keyDownListener.startMonitoringKeyEvents()
                    windowController.setIsFullscreen(false)
                }
        }
        .restorationBehavior(.disabled)
        .commands {
            AppCommands(updater: updaterController.updater)
            FileCommands(playEngine: $playEngine)
            ViewCommands(
                playEngine: $playEngine,
                windowController: $windowController)
            PlaybackCommands(
                playEngine: $playEngine,
                presentedViewManager: $presentedViewManager)
            WindowCommands(
                playEngine: $playEngine,
                windowController: $windowController)
            HelpCommands()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.count == 1, let url = urls.first else { return }
        Task {
            guard await PlayEngine.shared.openFile(url: url) else { return }
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApp.windows.first {
            window.isMovableByWindowBackground = true
        }
    }
}
