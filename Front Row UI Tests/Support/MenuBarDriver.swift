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

    /// How long AppKit is given to draw or dismiss a menu.
    private let menuTimeout: TimeInterval = 15

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
        open(menu, named: menuName)
        let item = menu.menuItems[itemTitle].firstMatch
        XCTAssertTrue(
            item.waitForExistence(timeout: menuTimeout),
            "The \(menuName) menu has no item called \(itemTitle)"
        )
        item.click()
        waitUntilClosed(menu, named: menuName)
    }

    private func withMenu<T>(_ menuName: String, _ body: (XCUIElement) -> T) -> T {
        let menu = app.menuBars.menuBarItems[menuName]
        open(menu, named: menuName)
        let result = body(menu)
        close(menu, named: menuName)
        return result
    }

    /// Clicks `menu` open and waits until it has items to read.
    private func open(_ menu: XCUIElement, named menuName: String) {
        menu.click()
        XCTAssertTrue(
            menu.menuItems.firstMatch.waitForExistence(timeout: menuTimeout),
            "The \(menuName) menu did not open"
        )
    }

    /// Clicks `menu` shut and waits until it is.
    private func close(_ menu: XCUIElement, named menuName: String) {
        menu.click()
        waitUntilClosed(menu, named: menuName)
    }

    /// Waits for `menu` to stop being the open one, which its title's selected state tracks.
    ///
    /// A menu left open swallows the next click, and every read after it answers for an empty
    /// menu, so this is worth failing on where it happens.
    private func waitUntilClosed(_ menu: XCUIElement, named menuName: String) {
        let deadline = Date().addingTimeInterval(menuTimeout)
        while menu.isSelected, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        XCTAssertFalse(menu.isSelected, "The \(menuName) menu would not close")
    }
}

extension FrontRowUITestCase {
    var menus: MenuBarDriver { MenuBarDriver(app: app) }
}
