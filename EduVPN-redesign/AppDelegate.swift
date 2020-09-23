//
//  AppDelegate.swift
//  eduVPN 2
//
//  Created by Johan Kool on 28/05/2020.
//

import PromiseKit

#if os(iOS)
import UIKit

@UIApplicationMain
class AppDelegate: NSObject, UIApplicationDelegate {

    var environment: Environment?

    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window
        return true
    }
    
}

#elseif os(macOS)
import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var mainWindow: NSWindow?
    var environment: Environment?
    var statusItemController: StatusItemController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        if UserDefaults.standard.showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let window = NSApp.windows[0]
        if let navigationController = window.rootViewController as? NavigationController {
            environment = Environment(navigationController: navigationController)
            navigationController.environment = environment
            if let mainController = navigationController.children.first as? MainViewController {
                mainController.environment = environment
            }
        }

        Self.replaceAppNameInMenuItems(in: NSApp.mainMenu)

        self.statusItemController = StatusItemController()

        setShowInStatusBarEnabled(UserDefaults.standard.showInStatusBar)
        setShowInDockEnabled(UserDefaults.standard.showInDock)

        if LaunchAtLoginHelper.isOpenedOrReopenedByLoginItemHelper() &&
            UserDefaults.standard.showInStatusBar {
            // If we're showing a status item and the app was launched because
            //  the user logged in, don't show the window
            window.close()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }

        self.mainWindow = window
    }

    private static func replaceAppNameInMenuItems(in menu: NSMenu?) {
        for menuItem in menu?.items ?? [] {
            menuItem.title = menuItem.title.replacingOccurrences(
                of: "APP_NAME", with: Config.shared.appName)
            for subMenuItem in menuItem.submenu?.items ?? [] {
                subMenuItem.title = subMenuItem.title.replacingOccurrences(
                    of: "APP_NAME", with: Config.shared.appName)
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let connectionService = environment?.connectionService else {
            return .terminateNow
        }

        guard connectionService.isVPNEnabled else {
            return .terminateNow
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString("Are you sure you want to quit \(Config.shared.appName)?", comment: "")
        alert.informativeText = NSLocalizedString("The active VPN connection will be stopped when you quit.", comment: "")
        alert.addButton(withTitle: NSLocalizedString("Stop VPN & Quit", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))

        func handleQuitConfirmationResult(_ result: NSApplication.ModalResponse) {
            if case .alertFirstButtonReturn = result {
                firstly {
                    connectionService.disableVPN()
                }.map { _ in
                    NSApp.terminate(nil)
                }.cauterize()
            }
        }

        if let window = NSApp.windows.first {
            alert.beginSheetModal(for: window) { result in
                handleQuitConfirmationResult(result)
            }
        } else {
            let result = alert.runModal()
            handleQuitConfirmationResult(result)
        }

        return .terminateCancel
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return !UserDefaults.standard.showInStatusBar
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if LaunchAtLoginHelper.isOpenedOrReopenedByLoginItemHelper() {
            return false
        }
        showMainWindow(self)
        setShowInDockEnabled(UserDefaults.standard.showInDock)
        return true
    }
}

extension AppDelegate {
    @objc func showMainWindow(_ sender: Any?) {
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showPreferences(_ sender: Any) {
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        environment?.navigationController?.presentPreferences()
    }

    @objc func newDocument(_ sender: Any) {
        guard let navigationController = environment?.navigationController else {
            return
        }
        if navigationController.isToolbarLeftButtonShowsAddServerUI {
            navigationController.toolbarLeftButtonClicked(self)
        }
    }

    func setShowInStatusBarEnabled(_ isEnabled: Bool) {
        statusItemController?.setShouldShowStatusItem(isEnabled)
    }

    func setShowInDockEnabled(_ isEnabled: Bool) {
        if isEnabled {
            if NSApp.activationPolicy() != .regular {
                NSApp.setActivationPolicy(.regular)
            }
        } else {
            if NSApp.activationPolicy() != .accessory {
                NSApp.setActivationPolicy(.accessory)
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                    NSApp.unhide(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }

    func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
        LaunchAtLoginHelper.setLaunchAtLoginEnabled(isEnabled)
    }
}

extension AppDelegate: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.keyEquivalent == "n" {
            return environment?.navigationController?.isToolbarLeftButtonShowsAddServerUI ?? false
        }
        return true
    }
}

#endif