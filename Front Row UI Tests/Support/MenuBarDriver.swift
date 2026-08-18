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
    private let menuTimeout: TimeInterval = 15

    /// How long a menu is given to take itself off the screen once it has been dealt with.
    private let dismissalTime: TimeInterval = 0.25

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
        open(menu)
        let item = menu.menuItems[itemTitle].firstMatch
        _ = item.waitForExistence(timeout: menuTimeout)
        item.click()
        Thread.sleep(forTimeInterval: dismissalTime)
    }

    private func withMenu<T>(_ menuName: String, _ body: (XCUIElement) -> T) -> T {
        let menu = app.menuBars.menuBarItems[menuName]
        open(menu)
        let result = body(menu)
        close(menu)
        return result
    }

    /// Clicks `menu` open and waits until it has items to read.
    ///
    /// Waited for rather than paced. A menu answers for its items only while it is open, so a
    /// fixed pause is really asking whether AppKit had finished drawing - and a menu caught
    /// half-drawn reads as one whose items have all gone, which is what the callers are looking
    /// for.
    private func open(_ menu: XCUIElement) {
        menu.click()
        _ = menu.menuItems.firstMatch.waitForExistence(timeout: menuTimeout)
    }

    /// Clicks `menu` shut.
    ///
    /// Paced rather than waited for, unlike opening. A closed menu goes on answering for its
    /// items, so there is no closed state to wait on - and nothing is read after this anyway, so
    /// a pause that ends early costs a retry rather than a wrong answer.
    ///
    /// Closed with a second click on the title rather than Escape, which reaches the app, where
    /// `KeyDownListener` answers it by hiding the app and the run never recovers.
    private func close(_ menu: XCUIElement) {
        menu.click()
        Thread.sleep(forTimeInterval: dismissalTime)
    }
}

extension FrontRowUITestCase {
    var menus: MenuBarDriver { MenuBarDriver(app: app) }
}
