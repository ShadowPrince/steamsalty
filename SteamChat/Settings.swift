//
//  Settings.swift
//  SteamChat
//
//  Created by shdwprince on 11/14/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import Foundation

protocol SettingsDelegate: AnyObject {
    func didChangeSetting(_ key: Settings.Keys, to value: Any)
}

class Settings {
    enum Keys: String {
        case version = "version"
        case sendByNewline = "sendByNewline"
        case pushNotifications = "pushNotifications"
        case isAuthenticated = "isAuthenticated"
    }

    static let shared = Settings()

    let version = 1.0
    var delegates = [SettingsDelegate]()

    init() {
        if UserDefaults.standard.double(forKey: Keys.version.rawValue) != self.version {
            UserDefaults.standard.setValuesForKeys([Keys.version.rawValue: self.version,
                                                    Keys.sendByNewline.rawValue: true,
                                                    Keys.pushNotifications.rawValue: false,
                                                    Keys.isAuthenticated.rawValue: false, ])
        }
    }

    func sendByNewline() -> Bool {
        return UserDefaults.standard.bool(forKey: Keys.sendByNewline.rawValue)
    }

    func pushNotifications() -> Bool {
        return UserDefaults.standard.bool(forKey: Keys.pushNotifications.rawValue)
    }

    func isAuthenticated() -> Bool {
        return UserDefaults.standard.bool(forKey: Keys.isAuthenticated.rawValue)
    }

    func set(value: Any?, for key: Keys) {
        self.delegates.forEach { $0.didChangeSetting(key, to: value) }
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
}
