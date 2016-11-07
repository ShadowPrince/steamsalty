
//  ChatViewController.swift
//  SteamChat
//
//  Created by shdwprince on 10/25/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import Foundation
import UIKit

class ActiveChatSessionsViewController: StackedContainersViewController {
    override func viewDidLoad() {
        self.dataSource = ChatSessionsManager.shared
    }
}

class ChatViewController: StackedContainerViewController, UITableViewDataSource, UITableViewDelegate, ChatSessionsManagerDelegate, UITextViewDelegate {
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
    @IBOutlet weak var emojisHeightConstraint: NSLayoutConstraint!

    private var isForeground: Bool = false
    private var index: Int?
    private var messages = [ParsedMessage]()
    private var session: ChatSessionsManager.Session!
    private var scrollToBottom = false
    
    private var textBounds = [Int: CGRect]()

    override func viewDidLoad() {
        self.newMessagesLabel.isHidden = true
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow(notification:)), name: NSNotification.Name.UIKeyboardDidShow, object: nil)

        self.emojisHeightConstraint.constant = 0.0
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func keyboardWillShow(notification: NSNotification) {
        let endFrame = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue

        self.bottomConstraint.constant = endFrame?.height ?? 0.0
        if self.shouldScrollToBottom() {
            self.scrollToBottom = true
        }
    }

    func keyboardDidShow(notification: NSNotification) {
        if self.scrollToBottom {
            self.scrollToBottom(animated: true)
            self.scrollToBottom = false
        }
    }

    func keyboardWillHide(notification: NSNotification) {
        self.bottomConstraint.constant = 0.0
    }

    func textViewDidChange(_ textView: UITextView) {
        if textView.text.characters.last == "\n" {
            let fullText = textView.text!
            let text = fullText.substring(to: fullText.index(fullText.endIndex, offsetBy: -1))
            
            SteamApi.shared.chatSay(text, to: self.session.user.id, handler: { (e) in
                if e == nil {
                    OperationQueue.main.addOperation {
                        textView.text = ""

                        let message = SteamChatMessage(author: ChatSessionsManager.shared.user.id, message: text, timestamp: UInt64(Date().timeIntervalSince1970))
                        self.session.messages.append(message)
                        self.appendMessages([message])
                        self.tableView.insertRows(at: [IndexPath(row: self.messages.count - 1, section: 0)], with: .automatic)
                        self.scrollToBottom(animated: true)
                    }
                } else {
                    OperationQueue.main.addOperation {
                        // show error
                    }
                }
            })
        }
    }

    @IBAction func emojisTapAction(_ sender: AnyObject) {
        self.emojisHeightConstraint.constant = self.emojisHeightConstraint.constant == 0.0 ? 100.0 : 0.0
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
        self.scrollToBottom(animated: true)

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
                    self.scrollToBottom(animated: true)
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

    func scrollToBottom(animated: Bool) {
        if !self.messages.isEmpty {
            self.tableView.scrollToRow(at: IndexPath(row: self.messages.count - 1, section: 0), at: .bottom, animated: animated)
        }
    }

    func shouldScrollToBottom() -> Bool {
        return self.tableView.contentOffset.y + self.tableView.frame.height > self.tableView.contentSize.height - 50.0
    }

    func appendMessages(_ messages: [SteamChatMessage]) {
        for msg in messages {
            self.messages.append(ParsedMessage(attributed: MessageParser.shared.parseMessage(msg.message), msg: msg))
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        for path in self.tableView.indexPathsForVisibleRows ?? [] {
            let cell = self.tableView.cellForRow(at: path)!
            let message = self.messages[path.row]
            let textView = cell.viewWithTag(1) as! ChatTextView
            let size = ChatTextView.textBounds(text: message.attributed, width: self.view.frame.width / 2)
            textView.setFrameTo(size, parent: self.view.frame)
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
