
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

class ChatViewController: StackedContainerViewController, ChatSessionsManagerDelegate, SettingsDelegate, UITextViewDelegate, UIGestureRecognizerDelegate {
    struct ParsedMessage {
        var attributed: NSAttributedString!
        var msg: SteamChatMessage!
    }

    static let hideKeyboardActionSelector = #selector(hideKeyboardAction(_:))
    static let sayTextAppendActionSelector = #selector(sayTextAppendAction(_:))
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var newMessagesLabel: NewMessagesLabel!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var personaStateLabel: PersonaStateLabel!
    @IBOutlet weak var sayTextView: UITextView!

    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var emojisHeightConstraint: NSLayoutConstraint!
    var emojisHeightConstant: CGFloat = 0.0
    @IBOutlet weak var sendWidthConstraint: NSLayoutConstraint!
    var sendWidthConstant: CGFloat = 0.0

    private var messagesViewController: MessagesTableViewController!
    private var emotesViewController: EmotesViewController!
    private let placeholderMessage = "Enter message..."
    private var scrollToBottom = false

    private var isForeground: Bool = false
    private var index: Int?
    private var session: ChatSessionsManager.Session!

    // MARK: - view
    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow(notification:)), name: NSNotification.Name.UIKeyboardDidShow, object: nil)

        self.emojisHeightConstant = self.emojisHeightConstraint.constant
        self.sendWidthConstant = self.sendWidthConstraint.constant

        self.newMessagesLabel.isHidden = true
        self.emojisHeightConstraint.constant = 0.0
        if Settings.shared.sendByNewline() {
            self.sendWidthConstraint.constant = 0.0
        }

        self.scrollToBottom = true
        
        self.titleLabel.text = "Select contact"
        self.personaStateLabel.text = ""
        self.backButtonVisibility(set: false)
        self.textViewDidEndEditing(self.sayTextView)
    }

    // since it's hard as nuts to create an array of weak 
    // references of a object conforming to type here goes this abomination
    // i'm not proud if it either
    override func viewWillDisappear(_ animated: Bool) {
        if let index = Settings.shared.delegates.index(where: { $0 === self }) {
            Settings.shared.delegates.remove(at: index)
        }
        super.viewWillDisappear(animated)
    }

    override func viewWillAppear(_ animated: Bool) {
        Settings.shared.delegates.append(self)
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        if self.scrollToBottom {
            self.scrollToBottom = false
            self.messagesViewController.scrollToBottom(animated: true)
        }

        super.viewDidAppear(animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if self.isForeground {
            self.backButtonVisibility(set: self.splitViewController?.isCollapsed ?? false)
        }
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
        case "toInfo"?:
            segue.destination.forcePopover(segue: segue)
            (segue.destination as! ContactInfoViewController).user = self.session.user
        default: break
        }

        super.prepare(for: segue, sender: sender)
    }

    // MARK: - actions

    @IBAction func backAction(_ sender: AnyObject) {
        let _ = self.navigationController?.popViewController(animated: true)
    }

    @IBAction func hideKeyboardAction(_ sender: AnyObject) {
        self.view.endEditing(true)
        self.emojisHeightConstraint.constant = 0.0
    }

    @IBAction func sayTextAppendAction(_ sender: AnyObject) {
        self.textViewDidBeginEditing(self.sayTextView)
        self.sayTextView.text.append(" \(sender) ")
    }

    @IBAction func emojisTapAction(_ sender: AnyObject) {
        UIView.animate(withDuration: 0.2,
                       animations: {
                        self.emojisHeightConstraint.constant = self.emojisHeightConstraint.constant == 0.0 ? self.emojisHeightConstant : 0.0
                        self.view.layoutSubviews() },
                       completion: { (d) in
                        self.messagesViewController.scrollToBottom(animated: true) })
    }

    @IBAction func sendMessageAction(_ sender: AnyObject) {
        let text = self.sayTextView.text!
        self.sayTextView.text = ""

        SteamApi.shared.chatSay(text, to: self.session.user.cid, handler: { (e) in
            if e == nil {
                OperationQueue.main.addOperation {
                    let message = SteamChatMessage(author: ChatSessionsManager.shared.user.id, message: text, timestamp: UInt64(Date().timeIntervalSince1970))
                    self.session.messages.append(message)
                    self.messagesViewController.insertMessages([message])
                }
            } else {
                OperationQueue.main.addOperation {
                    self.sayTextView.text = text
                    self.presentError(e!)
                }
            }
        })
    }

    // MARK: - keyboard
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


    // MARK: - text view
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" && Settings.shared.sendByNewline() {
            self.sendMessageAction(textView)
            return false
        } else {
            ChatSessionsManager.shared.typingNotify(session: self.session)
        }

        return true
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

    // MARK: - settings
    func didChangeSetting(_ key: Settings.Keys, to value: Any) {
        if key == .sendByNewline {
            switch value as? Bool {
            case true?:
                self.sendWidthConstraint.constant = 0.0
            case false?:
                self.sendWidthConstraint.constant = self.sendWidthConstant
            default:
                break
            }
        }
    }

    // MARK: - helpers
    func updateUnreadCounter() {
        self.newMessagesLabel.text = "\(self.session.unread)"
        self.newMessagesLabel.isHidden = self.session.unread == 0
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return touch.view != self.backButton
    }

    func backButtonVisibility(set to: Bool) {
        UIView.animate(withDuration: 0.3) {
            self.backButton.alpha = to ? 1.0 : 0.0
        }
    }

    // MARK: - stacked view
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

        self.personaStateLabel.setState(of: session.user)
        self.titleLabel.text = "\(self.session.user.name)"
        self.avatarImageView.loadImage(at: self.session.user.avatar)

        ChatSessionsManager.shared.delegates[index] = self
    }

    override func becomeForeground() {
        self.isForeground = true

        if self.session.unread > 0 {
            self.messagesViewController.scrollToBottom(animated: true)
        } else {
            self.messagesViewController.scrollToBottomIfShould()
        }

        ChatSessionsManager.shared.markAsRead(session: self.session)
        self.backButtonVisibility(set: self.splitViewController?.isCollapsed ?? false)
        self.newMessagesLabel.isHidden = true
    }

    override func becomeBackground() {
        self.isForeground = false

        self.backButtonVisibility(set: false)
    }

    // MARK: - session
    func sessionReceivedMessages(_ messages: [SteamChatMessage], in session: ChatSessionsManager.Session, from: ChatSessionsManager) {
        self.messagesViewController.insertMessages(messages)

        if self.isForeground {
            ChatSessionsManager.shared.markAsRead(session: self.session)
            OperationQueue.main.addOperation {
                self.messagesViewController.scrollToBottomIfShould()
            }
        }
    }

    func sessionOpenedExisting(_ session: ChatSessionsManager.Session, from: ChatSessionsManager) {
        self.scrollToBottom = true
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
        self.personaStateLabel.setState(of: session.user)
    }

    func sessionMarkedAsRead(_ session: ChatSessionsManager.Session, from: ChatSessionsManager) { }
}
