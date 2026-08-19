//
//  AppDelegate.swift
//  Front Row
//
//  Created by Joshua Park on 3/4/24.
//

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.count == 1, let url = urls.first else { return }
        Task {
            await openFileAndPresent(url: url)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MediaConversion.stopConversionForTermination()
        PlayEngine.shared.persistCurrentPlaybackPosition()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
