//
//  Settings.swift
//  SteamChat
//
//  Created by shdwprince on 11/14/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import Foundation
import UIKit

protocol SettingsDelegate: AnyObject {
    func didChangeSetting(_ key: Settings.Keys, to value: Any)
}

class Settings {
    enum Keys: String {
        case version = "version"
        case sendByNewline = "sendByNewline"
        case pushNotifications = "pushNotifications"
    }

    static let shared = Settings()

    let version = 1.0
    var delegates = [SettingsDelegate]()

    init() {
        if UserDefaults.standard.double(forKey: Keys.version.rawValue) != self.version {
            UserDefaults.standard.setValuesForKeys([Keys.version.rawValue: self.version,
                                                    Keys.sendByNewline.rawValue: true,
                                                    Keys.pushNotifications.rawValue: false, ])
        }
    }

    func sendByNewline() -> Bool {
        return UserDefaults.standard.bool(forKey: Keys.sendByNewline.rawValue)
    }

    func pushNotifications() -> Bool {
        return UserDefaults.standard.bool(forKey: Keys.pushNotifications.rawValue)
    }

    func set(value: Any?, for key: Keys) {
        self.delegates.forEach { $0.didChangeSetting(key, to: value) }
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
}

class SettingsViewController: UIViewController {
    @IBOutlet weak var sendByNewlineSwitch: UISwitch!
    @IBOutlet weak var notificationsSwitch: UISwitch!
    
    @IBAction func switchedSettings(_ sender: AnyObject) {
        if sender === self.sendByNewlineSwitch {
            Settings.shared.set(value: self.sendByNewlineSwitch.isOn, for: Settings.Keys.sendByNewline)
        }
        
        if sender === self.notificationsSwitch {
            if self.notificationsSwitch.isOn {
                let alert = UIAlertController(title: "You'd be warned",
                                              message: "Since the app is not official, notifications will only work for limited amount of time after switching to another app.",
                                              preferredStyle: .alert)

                alert.addAction(UIAlertAction(title: "Turn them on anyway", style: .destructive, handler: { (_) in
                    Settings.shared.set(value: true, for: Settings.Keys.pushNotifications)
                }))

                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
                    self.notificationsSwitch.isOn = false
                    self.dismiss(animated: true, completion: nil)
                }))

                self.present(alert, animated: true, completion: nil)
            } else {
                Settings.shared.set(value: false, for: Settings.Keys.pushNotifications)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.sendByNewlineSwitch.isOn = Settings.shared.sendByNewline()
        self.notificationsSwitch.isOn = Settings.shared.pushNotifications()
    }
}
