//
//  KeyDownListener.swift
//  Front Row
//
//  Created by Joshua Park on 5/26/25.
//

import Carbon.HIToolbox
import Cocoa

final class KeyDownListener {

    private var eventMonitor: Any?

    private enum KeyCommands {
        case escape

        static func fromEvent(_ event: NSEvent) -> KeyCommands? {
            // `keyCode` will raise exceptions if called on
            // events that are not key events
            guard event.type == .keyDown else { return nil }

            switch event.keyCode {
            case UInt16(kVK_Escape): return .escape
            default: return nil
            }
        }
    }

    public func startMonitoringKeyEvents() {
        if eventMonitor != nil {
            return
        }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let command = KeyCommands.fromEvent(event) else {
                return event
            }

            switch command {
            case .escape:
                let shouldHandle = MainActor.assumeIsolated {
                    let allWindows = NSApp.windows
                    let firstResponders = allWindows.compactMap { $0.firstResponder }
                    let fieldEditors = firstResponders.filter {
                        ($0 as? NSText)?.isEditable == true
                    }
                    guard fieldEditors.isEmpty else { return false }

                    if !WindowController.shared.isFullscreen {
                        NSApp.hide(nil)
                        PlayEngine.shared.pause()
                        return true
                    }
                    return false
                }
                return shouldHandle ? nil : event
            }
        }
    }

    public func stopMonitoringKeyEvents() {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }

        eventMonitor = nil
    }
}
