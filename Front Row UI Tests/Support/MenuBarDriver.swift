//
//  MenuBarDriver.swift
//  Front Row UI Tests
//

import XCTest

/// Reads and clicks main-menu items.
///
/// A menu's items only report their state while it is open, so every read opens the menu and
/// closes it again. Closing is a second click on the menu's own title: pressing Escape reaches the
/// app, where `KeyDownListener` answers it by hiding the app, and the run never recovers.
///
/// Only the titles asked for are looked up. Walking every item instead is slow enough to matter -
/// the Window menu carries around fifty, most of them AppKit's.
@MainActor
struct MenuBarDriver {

    let app: XCUIApplication

    /// How long AppKit is given to draw a menu before its items are read.
    private let menuSettleTime: TimeInterval = 0.5

    /// Whether each of `titles` is enabled, or `nil` where the menu has no such item.
    func states(of menuName: String, for titles: [String]) -> [String: Bool?] {
        withMenu(menuName) { menu in
            var states: [String: Bool?] = [:]
            for title in titles {
                let item = menu.menuItems[title].firstMatch
                states[title] = item.exists ? item.isEnabled : nil
            }
            return states
        }
    }

    /// Whether `menuName` currently offers an item called `title`.
    func contains(_ title: String, in menuName: String) -> Bool {
        withMenu(menuName) { $0.menuItems[title].firstMatch.exists }
    }

    func click(_ itemTitle: String, in menuName: String) {
        let menu = app.menuBars.menuBarItems[menuName]
        menu.click()
        Thread.sleep(forTimeInterval: menuSettleTime)
        menu.menuItems[itemTitle].firstMatch.click()
        Thread.sleep(forTimeInterval: menuSettleTime)
    }

    private func withMenu<T>(_ menuName: String, _ body: (XCUIElement) -> T) -> T {
        let menu = app.menuBars.menuBarItems[menuName]
        menu.click()
        Thread.sleep(forTimeInterval: menuSettleTime)
        let result = body(menu)
        menu.click()
        Thread.sleep(forTimeInterval: menuSettleTime / 2)
        return result
    }
}

extension FrontRowUITestCase {
    var menus: MenuBarDriver { MenuBarDriver(app: app) }
}
