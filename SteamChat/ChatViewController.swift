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
    override func awakeFromNib() {
        self.dataSource = ChatSessionsManager.shared
    }
}

class ChatViewController: StackedContainerViewController, UITableViewDataSource, UITableViewDelegate, ChatSessionsManagerDelegate {
    struct ParsedMessage {
        var attributed: NSAttributedString!
        var msg: SteamChatMessage!
    }
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var newMessagesLabel: NewMessagesLabel!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var personaStateLabel: PersonaStateLabel!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!

    private var isForeground: Bool = false
    private var index: Int?
    private var messages = [ParsedMessage]()
    private var session: ChatSessionsManager.Session!
    
    private var textBounds = [Int: CGRect]()

    override func viewDidLoad() {
        self.newMessagesLabel.isHidden = true
    }
    
    override func setIndex(_ index: Int) {
        if let lastIndex = self.index {
            ChatSessionsManager.shared.delegates.removeValue(forKey: lastIndex)
        }

        self.index = index
        self.session = ChatSessionsManager.shared.sessions[index]
        self.messages.removeAll()
        self.appendMessages(session.messages)
        self.personaStateLabel.setToState(session.user.state)

        self.tableView.reloadData()
        self.titleLabel.text = "\(self.session.user.name)"
        self.avatarImageView.loadImage(at: self.session.user.avatar)

        ChatSessionsManager.shared.delegates[index] = self
    }

    override func becomeForeground() {
        self.isForeground = true
        if self.session.unread > 0 {
            self.scrollToBottom()
        }

        ChatSessionsManager.shared.markAsRead(session: self.session)
        self.backButton.isHidden = false
        self.newMessagesLabel.isHidden = true
    }

    override func becomeBackground() {
        self.isForeground = false

        self.backButton.isHidden = true
    }

    func sessionReceivedMessages(_ messages: [SteamChatMessage], in session: ChatSessionsManager.Session, from: ChatSessionsManager) {
        let lastIndex = self.messages.count
        self.appendMessages(messages)

        var indexes = [IndexPath]()
        for i in lastIndex..<self.messages.count {
            indexes.append(IndexPath.init(row: i, section: 0))
        }

        self.tableView.insertRows(at: indexes, with: .automatic)

        if self.isForeground {
            ChatSessionsManager.shared.markAsRead(session: self.session)
            OperationQueue.main.addOperation {
                if self.shouldScrollToBottom() {
                    self.scrollToBottom()
                }
            }
        }
    }

    func sessionUpdatedNext(at index: Int, from: ChatSessionsManager) {
        if self.isForeground == false, let index = self.index {
            self.setIndex(index)
            OperationQueue.main.addOperation {
                self.updateUnreadCounter()
            }
        }
    }

    func sessionUpdatedStatus(_ session: ChatSessionsManager.Session, from: ChatSessionsManager) {
        self.personaStateLabel.setToState(session.user.state)
    }

    func sessionMarkedAsRead(_ session: ChatSessionsManager.Session, from: ChatSessionsManager) { }

    func updateUnreadCounter() {
        self.newMessagesLabel.text = "\(self.session.unread)"
        self.newMessagesLabel.isHidden = self.session.unread == 0
    }

    func scrollToBottom() {
        if !self.messages.isEmpty {
            self.tableView.scrollToRow(at: IndexPath(row: self.messages.count - 1, section: 0), at: .bottom, animated: true)
        }
    }

    func shouldScrollToBottom() -> Bool {
        return true
    }

    func appendMessages(_ messages: [SteamChatMessage]) {
        for msg in messages {
            self.messages.append(ParsedMessage(attributed: MessageParser.shared.parseMessage(msg.message), msg: msg))
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.messages.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let width = (self.view.frame.width / 2)
        return ChatTextView.textBounds(text: self.messages[indexPath.row].attributed, width: width).height + ChatTextView.offset * 2
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = self.messages[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: message.msg.author == self.session.user.id ? "ingoingCell" : "outgoingCell")!
        let textView = cell.viewWithTag(1) as! ChatTextView
        textView.attributedText = message.attributed

        let size = ChatTextView.textBounds(text: message.attributed, width: self.view.frame.width / 2)
        textView.setFrameTo(size, parent: self.view.frame)

        return cell
    }

    @IBAction func backAction(_ sender: AnyObject) {
        self.navigationController?.popViewController(animated: true)
    }
}
