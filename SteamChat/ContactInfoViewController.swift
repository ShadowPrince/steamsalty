//
//  ContactInfoViewController.swift
//  SteamChat
//
//  Created by shdwprince on 11/15/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import Foundation
import UIKit

class ContactInfoViewController: UIViewController, UIScrollViewDelegate, SteamPollManagerDelegate {
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var avatarView: AvatarFadedImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var stateLabel: PersonaStateLabel!
    @IBOutlet weak var gameLabel: UILabel!
    @IBOutlet weak var profileWebView: UIWebView!

    var user: SteamUser!
    var originalContentSize: CGSize!

    override func awakeFromNib() {
        super.awakeFromNib()

        self.originalContentSize = self.preferredContentSize
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        SteamPollManager.shared.delegates.append(self)

        self.avatarView.loadImage(at: user.fullAvatar)
        self.nameLabel.text = user.name
        self.updateUserStatus()
        self.profileWebView.loadBackgroundColor(UIColor.black)
        self.profileWebView.loadRequest(URLRequest(url: user.communityProfile))
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        SteamPollManager.shared.delegates.remove(at: SteamPollManager.shared.delegates.index(where: { $0 === self })!)
    }

    func pollReceived(events: [SteamEvent], manager: SteamPollManager) {
        events.filter { $0.type == .userUpdate && $0.from == self.user.id }
              .forEach { self.user = ($0 as! SteamUserUpdateEvent).user }

        OperationQueue.main.addOperation {
            self.updateUserStatus()
        }

        /*
         I wonder if this is better
        for event in events {
            if event.type == .userUpdate && event.from == self.user.id,
               let updateEvent = event as? SteamUserUpdateEvent {
                self.user = updateEvent.user
                OperationQueue.main.addOperation {
                    self.updateUserStatus()
                }
            }
        }
         */
    }
    
    func pollError(_ error: Error, manager: SteamPollManager) { }
    func pollStatus(_ user: SteamUser, contacts: [SteamUser], emotes: [SteamEmoteName]) { }

    func updateUserStatus() {
        self.stateLabel.setState(of: user)
        self.gameLabel.text = user.currentGame?.name ?? ""
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y == 0.0 {
            self.preferredContentSize = self.originalContentSize
        } else {
            let bounds = UIScreen.main.bounds
            self.preferredContentSize = CGSize(width: bounds.width - 16.0,
                                               height: bounds.height * 0.75)
        }
    }

    @IBAction func shareAction(_ sender: AnyObject) {
        let safariActivity = UniversalActivity.instanceTitled("Open in Safari", icon:#imageLiteral(resourceName: "safari") ) {
            UIApplication.shared.openURL(self.user.communityProfile)
        }

        let activity = UIActivityViewController(activityItems: [self.user.communityProfile],
                                                applicationActivities: [safariActivity, ])
        self.present(activity, animated: true, completion: nil)
    }
}
