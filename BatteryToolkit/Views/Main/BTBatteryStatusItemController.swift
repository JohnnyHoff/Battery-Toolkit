//
// Copyright (C) 2024 Marvin Häuser. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
//

import Cocoa
import notify
import os.log

@MainActor
internal final class BTBatteryStatusItemController {
    private let statusItem: NSStatusItem
    private let templateImage: NSImage?

    private var notifyToken: Int32? = nil
    private var showsPercentage = false
    private var isStopped = false

    init(menu: NSMenu) {
        self.statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        self.statusItem.menu = menu
        self.statusItem.button?.alignment = .center

        let image = NSImage(named: NSImage.Name("ExtraItemIcon"))
        image?.isTemplate = true
        self.templateImage = image

        self.applyTemplateImage()
    }

    deinit {
        self.stop()
    }

    func setShowsPercentage(_ showsPercentage: Bool) {
        guard !self.isStopped else {
            return
        }

        self.showsPercentage = showsPercentage

        if showsPercentage {
            self.startPercentNotifications()
        } else {
            self.stopPercentNotifications()
            self.applyTemplateImage()
        }
    }

    func stop() {
        guard !self.isStopped else {
            return
        }

        self.stopPercentNotifications()
        NSStatusBar.system.removeStatusItem(self.statusItem)
        self.isStopped = true
    }

    private func startPercentNotifications() {
        self.refreshPercentDisplay()

        guard self.notifyToken == nil else {
            return
        }

        var token: Int32 = 0
        let status = notify_register_dispatch(
            IOPSPrivate.kIOPSNotifyPercentChange,
            &token,
            DispatchQueue.main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPercentDisplay()
            }
        }
        guard status == NOTIFY_STATUS_OK else {
            os_log("Failed to register percent change notification - \(status)")
            return
        }

        self.notifyToken = token
    }

    private func stopPercentNotifications() {
        if let token = self.notifyToken {
            notify_cancel(token)
            self.notifyToken = nil
        }
    }

    private func refreshPercentDisplay() {
        guard self.showsPercentage else {
            return
        }

        guard let (percent, _, _) = IOPSPrivate.GetPercentRemaining() else {
            self.applyTemplateImage()
            return
        }

        self.statusItem.button?.image = nil
        self.statusItem.button?.imagePosition = .noImage
        self.statusItem.button?.title = String(format: "%d%%", Int(percent))
    }

    private func applyTemplateImage() {
        self.statusItem.button?.title = ""
        self.statusItem.button?.image = self.templateImage
        self.statusItem.button?.imagePosition = .imageOnly
    }
}
