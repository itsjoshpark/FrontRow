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
    @State private var playEngine = PlayEngine.shared
    @State private var presentedViewManager = PresentedViewManager.shared
    @State private var windowController = WindowController.shared
    private let updaterController: SPUStandardUpdaterController
    private let keyDownListener = KeyDownListener()

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        keyDownListener.startMonitoringKeyEvents()

        UserDefaults.standard.set(false, forKey: "NSFullScreenMenuItemEverywhere")
    }

    var body: some Scene {
        Window("Front Row", id: WindowID.main) {
            ContentView()
                .preferredColorScheme(.dark)
                .ignoresSafeArea()
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
                .onReceive(
                    NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)
                ) { notification in
                    guard let closingWindow = notification.object as? NSWindow,
                        closingWindow == windowController.mainWindow
                    else { return }
                    playEngine.pause()
                }
                .background(
                    WindowAccessor { window in
                        window.isMovableByWindowBackground = true
                        windowController.mainWindow = window
                    }
                )
        }
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .environment(playEngine)
        .environment(presentedViewManager)
        .environment(windowController)
        .commands {
            AppCommands(updater: updaterController.updater)
            FileCommands()
            ViewCommands()
            PlaybackCommands()
            WindowCommands()
            HelpCommands()
        }

        Window("Welcome to Front Row", id: WindowID.welcome) {
            WelcomeView()
                .preferredColorScheme(.dark)
                .environment(presentedViewManager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.presented)
        .defaultPosition(.center)
        .restorationBehavior(.disabled)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.count == 1, let url = urls.first else { return }
        Task {
            await openFileAndPresent(url: url)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        PlayEngine.shared.persistCurrentPlaybackPosition()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
