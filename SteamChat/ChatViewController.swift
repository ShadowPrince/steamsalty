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
    @IBOutlet weak var backButton: UIButton!

    private var index: Int?
    private var user: SteamUser!
    private var messages = [SteamChatMessage]()
    private var textBounds = [Int: CGRect]()

    override func viewDidLoad() {
        self.view.layer.borderWidth = 1.0
        self.view.layer.borderColor = UIColor.gray.cgColor
        self.view.layer.cornerRadius = 5.0
    }
    
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
        self.view.layer.borderWidth = 1.0
        self.backButton.isHidden = false
    }

    override func becomeBackground() {
        self.view.layer.borderWidth = 0.0
        self.backButton.isHidden = true
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
        let width = (self.view.frame.width / 2)
        return ChatTextView.textBounds(text: self.messages[indexPath.row].message, width: width).height + ChatTextView.offset * 2
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = self.messages[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: message.isIngoing() ? "ingoingCell" : "outgoingCell")!
        let textView = cell.viewWithTag(1) as! ChatTextView
        textView.text = message.message

        let size = ChatTextView.textBounds(text: message.message, width: self.view.frame.width / 2)
        textView.setFrameTo(size, parent: self.view.frame)

        return cell
    }

    @IBAction func backAction(_ sender: AnyObject) {
        self.navigationController?.popViewController(animated: true)
    }
}

@IBDesignable
class ChatTextView: UITextView {
    static let offset: CGFloat = 10.0
    static let inset: CGFloat = 5.0
    static let combined: CGFloat = offset + inset

    @IBInspectable
    var isIngoing: Bool = true

    static func textBounds(text: String, width: CGFloat) -> CGRect {
        var bounds = (text as NSString).boundingRect(with: CGSize.init(width: width, height: CGFloat(MAXFLOAT)),
                                                     options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                     attributes: [NSFontAttributeName: UIFont.systemFont(ofSize: UIFont.systemFontSize)],
                                                     context: nil)
        bounds = CGRect(x: bounds.origin.x, y: bounds.origin.y, width: bounds.width + ChatTextView.inset * 2, height: bounds.height + ChatTextView.inset * 2)
        return bounds
    }

    func setFrameTo(_ size: CGRect, parent: CGRect) {
        let width = size.width
        let x = self.isIngoing ? ChatTextView.offset : parent.width - width - ChatTextView.offset
        self.frame = CGRect(x: x,
                            y: ChatTextView.offset,
                            width: width,
                            height: size.height)
    }
    
    override func didMoveToSuperview() {
        self.textContainerInset = .init(top: ChatTextView.inset, left: ChatTextView.inset, bottom: ChatTextView.inset, right: ChatTextView.inset)
        self.textContainer.lineFragmentPadding = 0.0

        self.layer.cornerRadius = 10.0
        self.layer.borderWidth = 1.0
        self.layer.borderColor = self.tintColor.cgColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()
    }
}
