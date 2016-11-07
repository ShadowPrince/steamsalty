
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

class ChatViewController: StackedContainerViewController, ChatSessionsManagerDelegate, UITextViewDelegate {
    struct ParsedMessage {
        var attributed: NSAttributedString!
        var msg: SteamChatMessage!
    }

    static let hideKeyboardActionSelector = #selector(hideKeyboardAction(_:))
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var newMessagesLabel: NewMessagesLabel!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var personaStateLabel: PersonaStateLabel!
    @IBOutlet weak var sayTextView: UITextView!

    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var emojisHeightConstraint: NSLayoutConstraint!

    private var messagesViewController: MessagesTableViewController!
    private var emotesViewController: EmotesViewController!
    private let placeholderMessage = "Enter message..."
    private var scrollToBottom = false

    private var isForeground: Bool = false
    private var index: Int?
    private var session: ChatSessionsManager.Session!

    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow(notification:)), name: NSNotification.Name.UIKeyboardDidShow, object: nil)

        self.newMessagesLabel.isHidden = true
        self.emojisHeightConstraint.constant = 0.0
        self.emotesViewController.action = { self.sayTextView.text.append(" \($0) ") }
        self.textViewDidEndEditing(self.sayTextView)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "emotesViewController"?:
            self.emotesViewController = segue.destination as! EmotesViewController
        case "messagesViewController"?:
            self.messagesViewController = segue.destination as! MessagesTableViewController
        default: break
        }

        super.prepare(for: segue, sender: sender)
    }

    @IBAction func backAction(_ sender: AnyObject) {
        self.navigationController?.popViewController(animated: true)
    }

    @IBAction func hideKeyboardAction(_ sender: AnyObject) {
        self.view.endEditing(true)
    }

    func keyboardWillShow(notification: NSNotification) {
        let endFrame = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        
        self.bottomConstraint.constant = endFrame?.height ?? 0.0
        if self.messagesViewController.shouldScrollToBottom() {
            self.scrollToBottom = true
        }
    }

    func keyboardDidShow(notification: NSNotification) {
        if self.scrollToBottom {
            self.messagesViewController.scrollToBottom(animated: true)
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
            
            SteamApi.shared.chatSay(text, to: self.session.user.cid, handler: { (e) in
                if e == nil {
                    OperationQueue.main.addOperation {
                        textView.text = ""

                        let message = SteamChatMessage(author: ChatSessionsManager.shared.user.id, message: text, timestamp: UInt64(Date().timeIntervalSince1970))
                        self.session.messages.append(message)
                        self.messagesViewController.insertMessages([message])
                    }
                } else {
                    OperationQueue.main.addOperation {
                        self.presentError(e!)
                    }
                }
            })
        }
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.text == self.placeholderMessage {
            textView.text = ""
            textView.textColor = UIColor.white
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text == "" {
            textView.text = self.placeholderMessage
            textView.textColor = UIColor.gray
        }
    }

    @IBAction func emojisTapAction(_ sender: AnyObject) {
        UIView.animate(withDuration: 0.2) {
            self.emojisHeightConstraint.constant = self.emojisHeightConstraint.constant == 0.0 ? 60.0 : 0.0
            self.view.layoutSubviews()
        }
    }

    override func setIndex(_ index: Int) {
        if let lastIndex = self.index {
            ChatSessionsManager.shared.delegates.removeValue(forKey: lastIndex)
        }

        self.index = index

        self.session = ChatSessionsManager.shared.sessions[index]
        self.messagesViewController.session = self.session
        self.messagesViewController.empty()
        self.messagesViewController.appendMessages(self.session.messages)
        self.messagesViewController.reload()

        self.personaStateLabel.setToState(session.user.state)
        self.titleLabel.text = "\(self.session.user.name)"
        self.avatarImageView.loadImage(at: self.session.user.avatar)

        ChatSessionsManager.shared.delegates[index] = self
    }

    override func becomeForeground() {
        self.isForeground = true
        self.messagesViewController.scrollToBottom(animated: true)

        ChatSessionsManager.shared.markAsRead(session: self.session)
        self.backButton.isHidden = false
        self.newMessagesLabel.isHidden = true
    }

    override func becomeBackground() {
        self.isForeground = false

        self.backButton.isHidden = true
    }

    func sessionReceivedMessages(_ messages: [SteamChatMessage], in session: ChatSessionsManager.Session, from: ChatSessionsManager) {
        self.messagesViewController.insertMessages(messages)

        if self.isForeground {
            ChatSessionsManager.shared.markAsRead(session: self.session)
            OperationQueue.main.addOperation {
                self.messagesViewController.scrollToBottomIfShould()
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
}
