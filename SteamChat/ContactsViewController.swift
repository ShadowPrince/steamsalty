//
//  ContactsViewController.swift
//  SteamChat
//
//  Created by shdwprince on 10/30/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import Foundation
import UIKit

class ContactsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, SteamPollManagerDelegate, ChatSessionManagerDelegate {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var selfAvatarImageView: AvatarImageView!
    @IBOutlet weak var selfNameLabel: UILabel!
    @IBOutlet weak var selfStateLabel: UILabel!

    var users = [SteamUser]()
    let pollQueue = OperationQueue()

    override func viewWillAppear(_ animated: Bool) {
        ChatSessionsManager.shared.delegates[-1] = self
        SteamPollManager.shared.delegates.append(self)
        SteamApi.shared.status { (user, friends, error) in
            if error == nil {
                self.users = friends!
                self.users.sort(by: { $0.0.name > $0.1.name })

                OperationQueue.main.addOperation {
                    self.selfAvatarImageView.loadImage(at: user!.avatar)
                    self.selfNameLabel.text = user?.name
                    self.selfStateLabel.text = "---"
                    self.tableView.reloadData()
                }
            }
        }
    }

    func pollReceived(event: SteamEvent, manager: SteamPollManager) {
        switch event.type {
        case .personaState:
            let e = event as! SteamPersonaStateEvent
            if let index = self.users.index(where: { $0.id == e.from }) {
                self.users[index].state = e.state
                OperationQueue.main.addOperation {
                    self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                }
            }
        default: break
        }
    }

    func pollError(_ error: Error, manager: SteamPollManager) {

    }

    func markedSessionAsRead(_ session: ChatSession) {
        let index = self.users.index(where: { $0 == session.user}) {

        }
    }

    func receivedMessages(_ messages: [SteamChatMessage]) { }
    func updatedNextElement() { }
    func updateUserStatus() { }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.users.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")!
        let user = self.users[indexPath.row]
        (cell.viewWithTag(1) as! UILabel).text = user.name
        (cell.viewWithTag(2) as! AvatarImageView).loadImage(at: user.avatar)
        (cell.viewWithTag(3) as! PersonaStateLabel).setToState(user.state)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: "toChat", sender: self.users[indexPath.row])
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toChat" {
            ChatSessionsManager.shared.openChat(with: sender as! SteamUser)
        }
    }
}
