//
//  SettingsViewController.swift
//  SteamChat
//
//  Created by shdwprince on 11/14/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import Foundation
import UIKit

class SettingsViewController: UIViewController {
    @IBOutlet weak var sendByNewlineSwitch: UISwitch!
    //@IBOutlet weak var notificationsSwitch: UISwitch!
    
    @IBAction func switchedSettings(_ sender: AnyObject) {
        if sender === self.sendByNewlineSwitch {
            Settings.shared.set(value: self.sendByNewlineSwitch.isOn, for: Settings.Keys.sendByNewline)
        }

        /*
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
 */
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.sendByNewlineSwitch.isOn = Settings.shared.sendByNewline()
        //self.notificationsSwitch.isOn = Settings.shared.pushNotifications()
    }
}
