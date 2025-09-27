//
// Copyright (C) 2022 - 2024 Marvin Häuser. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
//

import Cocoa
import os.log

@main
@MainActor
internal final class BTAppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarStatusItemController: BTBatteryStatusItemController?
    private var showMenuBarPercentageObserver: NSObjectProtocol?
    @IBOutlet private var menuBarExtraMenu: NSMenu!

    @IBOutlet private var settingsItem: NSMenuItem!
    @IBOutlet private var disableBackgroundItem: NSMenuItem!
    @IBOutlet private var commandsMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_: Notification) {
        Task {
            let status = await BTActions.startDaemon()
            await self.daemonStatusHandler(status: status)
        }
    }

    func applicationWillTerminate(_: Notification) {
        self.teardownMenuBarStatusItem()

        Task { @BTBackgroundActor in
            BTActions.stop()
        }
    }

    func applicationWillBecomeActive(_: Notification) {
        //
        // Use the menuBarStatusItemController value as an indicator for whether the app
        // has fully initialized.
        //
        guard self.menuBarStatusItemController != nil else {
            return
        }

        BTAccessoryMode.deactivate()
    }

    func applicationWillResignActive(_: Notification) {
        guard self.menuBarStatusItemController != nil else {
            return
        }

        BTAccessoryMode.activate()
    }

    @IBAction private func removeDaemonHandler(sender _: NSMenuItem) {
        Task {
            await BTAppPrompts.promptRemoveDaemon()
        }
    }

    private func daemonStatusHandler(status: BTDaemonManagement.Status) async {
        switch status {
        case .notRegistered:
            os_log("Daemon not registered")

            self.teardownMenuBarStatusItem()

            if BTAppPrompts.promptRegisterDaemonError() {
                let status = await BTActions.startDaemon()
                await self.daemonStatusHandler(status: status)
            }

        case .enabled:
            os_log("Daemon is enabled")

            do {
                try await BTDaemonXPCClient.isSupported()
                self.disableBackgroundItem.isEnabled = true
                self.settingsItem.isEnabled = true
                self.commandsMenuItem.isHidden = false

                if self.menuBarStatusItemController == nil {
                    self.menuBarStatusItemController = BTBatteryStatusItemController(
                        menu: self.menuBarExtraMenu
                    )
                }

                self.installMenuBarPercentageObserver()

                let showPercentage = UserDefaults.standard.bool(
                    forKey: BTAppPreferences.Keys.showMenuBarPercentage
                )
                self.menuBarStatusItemController?.setShowsPercentage(showPercentage)

                if !NSApp.isActive {
                    BTAccessoryMode.activate()
                }
            } catch BTError.unsupported {
                self.teardownMenuBarStatusItem()
                await BTAppPrompts.promptMachineUnsupported()
            } catch {
                self.teardownMenuBarStatusItem()
                BTErrorHandler.errorHandler(error: error)
            }

        case .requiresApproval:
            os_log("Daemon requires approval")

            self.teardownMenuBarStatusItem()

            do {
                try await BTAppPrompts.promptApproveDaemon(timeout: 20)
                await self.daemonStatusHandler(status: .enabled)
            } catch {
                await self.daemonStatusHandler(status: .requiresApproval)
            }

        case .requiresUpgrade:
            os_log("Daemon requires upgrade")

            self.teardownMenuBarStatusItem()

            let storyboard = NSStoryboard(
                name: "Upgrading",
                bundle: nil
            )
            let upgradingController = storyboard
                .instantiateInitialController() as! NSWindowController
            upgradingController.window?.center()
            upgradingController.showWindow(self)

            let status = await BTActions.upgradeDaemon()
            upgradingController.close()
            await self.daemonStatusHandler(status: status)
        }
    }

    private func installMenuBarPercentageObserver() {
        guard self.showMenuBarPercentageObserver == nil else {
            return
        }

        self.showMenuBarPercentageObserver = NotificationCenter.default.addObserver(
            forName: .btShowMenuBarPercentageChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else {
                return
            }

            let storedValue = UserDefaults.standard.bool(
                forKey: BTAppPreferences.Keys.showMenuBarPercentage
            )

            guard let valueNumber = notification.userInfo?[
                BTAppPreferences.NotificationUserInfoKey.value
            ] as? NSNumber else {
                self.menuBarStatusItemController?.setShowsPercentage(storedValue)
                return
            }

            self.menuBarStatusItemController?.setShowsPercentage(valueNumber.boolValue)
        }
    }

    private func teardownMenuBarStatusItem() {
        if let observer = self.showMenuBarPercentageObserver {
            NotificationCenter.default.removeObserver(observer)
            self.showMenuBarPercentageObserver = nil
        }

        self.menuBarStatusItemController?.stop()
        self.menuBarStatusItemController = nil
    }
}
