//
//  ContactsViewController.swift
//  SteamChat
//
//  Created by shdwprince on 10/30/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import Foundation
import UIKit

extension Array where Element: ContactsViewController.Item {
    func index(of userId: SteamUserId) -> Int? {
        return self.index(where: { $0.user.id == userId })
    }

    func index(of user: SteamUser) -> Int? {
        return self.index(where: { $0.user == user })
    }
}

class ContactsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, SteamPollManagerDelegate, ChatSessionsManagerDelegate {
    class Item: CustomStringConvertible {
        var user: SteamUser
        var session: ChatSessionsManager.Session?
        var lastUpdated: Date

        init(user: SteamUser, session: ChatSessionsManager.Session?) {
            self.user = user
            self.session = session
            self.lastUpdated = Date()
        }

        var description: String {
            return self.user.name
        }
    }

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var selfAvatarImageView: AvatarImageView!
    @IBOutlet weak var selfNameLabel: UILabel!
    @IBOutlet weak var selfStateLabel: PersonaStateLabel!

    var items = [Item]()
    let pollQueue = OperationQueue()

    override func viewDidLoad() {
        ChatSessionsManager.shared.delegates[-1] = self
        SteamPollManager.shared.delegates.append(self)
    }

    // polling
    func pollReceived(events: [SteamEvent], manager: SteamPollManager) {
        var indexPaths = [IndexPath]()
        for event in events {
            switch event.type {
            case .personaState:
                let e = event as! SteamPersonaStateEvent
                if let index = self.items.index(of: e.from) {
                    self.items[index].user.state = e.state
                    indexPaths.append(IndexPath(row: index, section: 0))
                }
            default: break
            }
        }
                    
        OperationQueue.main.addOperation {
            self.tableView.reloadRows(at: indexPaths, with: .automatic)
        }
    }

    func pollStatus(_ user: SteamUser, contacts: [SteamUser], emotes: [String]) {
        self.items.removeAll()
        for user in contacts {
            let item = Item(user: user, session: nil)
            item.lastUpdated = user.lastMessageDate
            
            self.items.append(item)
        }

        OperationQueue.main.addOperation {
            self.selfAvatarImageView.loadImage(at: user.avatar)
            self.selfNameLabel.text = user.name
            self.selfStateLabel.setToState(user.state)
            self.tableView.reloadData()
        }
    }

    func pollError(_ error: Error, manager: SteamPollManager) {
        switch error {
        case SteamApi.RequestError.AuthFailed:
            break
        default:
            OperationQueue.main.addOperation {
                self.presentError(error)
            }
        }
    }

    // chat sessions
    func sessionReceivedMessages(_ messages: [SteamChatMessage], in session: ChatSessionsManager.Session, from: ChatSessionsManager) {
        if let i = self.items.index(of: session.user) {
            self.items[i].lastUpdated = Date()
            self.items[i].session = session
            self.items.sort(by: { $0.0.lastUpdated > $0.1.lastUpdated })
            OperationQueue.main.addOperation {
                self.tableView.reloadData()
            }
        }
    }

    func sessionMarkedAsRead(_ session: ChatSessionsManager.Session, from: ChatSessionsManager) {
        if let i = self.items.index(of: session.user) {
            self.items[i].session = session
            OperationQueue.main.addOperation {
                self.tableView.reloadRows(at: [IndexPath(row: i, section: 0)], with: .automatic)
            }
        }
    }

    func sessionUpdatedStatus(_ session: ChatSessionsManager.Session, from: ChatSessionsManager) { }
    func sessionUpdatedNext(at index: Int, from: ChatSessionsManager) { }
    func sessionOpenedExisting(_ session: ChatSessionsManager.Session, from: ChatSessionsManager) { }

    // table
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")!
        let item = self.items[indexPath.row]
        (cell.viewWithTag(1) as! UILabel).text = item.user.name
        (cell.viewWithTag(2) as! AvatarImageView).loadImage(at: item.user.avatar)
        (cell.viewWithTag(3) as! PersonaStateLabel).setToState(item.user.state)
        
        let unreadLabel = cell.viewWithTag(4) as! UILabel
        let unreadMessages = item.session?.unread ?? 0
        unreadLabel.isHidden = unreadMessages == 0
        unreadLabel.text = "\(unreadMessages)"
        
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: "toChat", sender: self.items[indexPath.row])
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toChat" {
            ChatSessionsManager.shared.openChat(with: (sender as! Item).user)
        } else if segue.identifier == "toSettings" {
            segue.destination.modalPresentationStyle = .popover
            segue.destination.popoverPresentationController?.delegate = PopoverStyleDelegate.shared
        }

        super.prepare(for: segue, sender: sender)
    }
}
