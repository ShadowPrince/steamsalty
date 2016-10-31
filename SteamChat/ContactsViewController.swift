//
//  ContactsViewController.swift
//  SteamChat
//
//  Created by shdwprince on 10/30/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import Foundation
import UIKit

class ContactsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, SteamPollManagerDelegate {
    @IBOutlet weak var tableView: UITableView!

    var users = [SteamUser]()
    let pollQueue = OperationQueue()

    override func viewWillAppear(_ animated: Bool) {
        SteamPollManager.shared.delegates.append(self)
        SteamApi.shared.status { (user, friends, error) in
            if error == nil {
                self.users = friends!
                OperationQueue.main.addOperation {
                    self.tableView.reloadData()
                }
            }
        }
    }

    func pollReceived(event: SteamEvent, manager: SteamPollManager) {
        switch event.type {
        case .personaState:
            let e = event as! SteamPersonaStateEvent
            if var user = self.users.first(where: { $0.id == e.from }) {
                user.state = e.state
            }
        default: break
        }
    }

    func pollError(_ error: Error, manager: SteamPollManager) {

    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.users.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")!
        (cell.viewWithTag(1) as! UILabel).text = self.users[indexPath.row].name
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
