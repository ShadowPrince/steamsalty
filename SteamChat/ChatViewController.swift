//
//  ChatViewController.swift
//  SteamChat
//
//  Created by shdwprince on 10/25/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import Foundation
import UIKit

class ActiveChatSessionsViewController: StackedContainersViewController {
    override func viewWillAppear(_ animated: Bool) {
        self.dataSource = ChatSessionsManager.shared

        super.viewWillAppear(animated)
    }
}

class ChatViewController: StackedContainerViewController, UITableViewDataSource, UITableViewDelegate, ChatSessionManagerDelegate {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var titleLabel: UILabel!

    private var index: Int?
    private var user: SteamUser!
    private var messages = [SteamChatMessage]()

    override func setIndex(_ index: Int) {
        if let lastIndex = self.index {
            ChatSessionsManager.shared.delegates.removeValue(forKey: lastIndex)
        }

        let session = ChatSessionsManager.shared.sessions[index]
        self.user = session.user
        self.messages = session.messages

        self.tableView.reloadData()
        self.titleLabel.text = self.user.name

        self.index = index
        ChatSessionsManager.shared.delegates[index] = self
    }

    override func becomeForeground() {
    }

    override func becomeBackground() {
    }

    func receivedMessages(_ messages: [SteamChatMessage]) {
        let lastIndex = self.messages.count
        self.messages.append(contentsOf: messages)

        var indexes = [IndexPath]()
        for i in lastIndex..<self.messages.count {
            indexes.append(IndexPath.init(row: i, section: 0))
        }

        self.tableView.insertRows(at: indexes, with: .automatic)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.messages.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let text = self.messages[indexPath.row].message
        let width = self.view.frame.width
        let bounds = (text as NSString).boundingRect(with: CGSize.init(width: width, height: CGFloat(MAXFLOAT)),
                                                     options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                     attributes: [NSFontAttributeName: UIFont.systemFont(ofSize: UIFont.systemFontSize)],
                                                     context: nil)

        return bounds.height
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")!
        let textView = cell.viewWithTag(1) as! UITextView

        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0.0

        textView.frame = cell.bounds
        textView.text = self.messages[indexPath.row].message

        return cell
    }
    
    @IBAction func backAction(_ sender: AnyObject) {
        self.navigationController?.popViewController(animated: true)
    }
}
