//
// Copyright (C) 2024 Marvin Häuser. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
//

import Foundation

enum BTAppPreferences {
    enum Keys {
        static let showMenuBarPercentage = "showMenuBarPercentage"
    }

    enum NotificationUserInfoKey {
        static let value = "value"
    }
}

extension Notification.Name {
    static let btShowMenuBarPercentageChanged = Notification.Name(
        "BTShowMenuBarPercentageChanged"
    )
}
