//
//  MessagesTableViewController.swift
//  SteamChat
//
//  Created by shdwprince on 11/7/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import Foundation
import UIKit

class MessagesTableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    struct ParsedMessage {
        var attributed: NSAttributedString!
        var msg: SteamChatMessage!
    }

    @IBOutlet weak var tableView: UITableView!
    var messages = [ParsedMessage]()
    var session: ChatSessionsManager.Session!

    func scrollToBottom(animated: Bool) {
        if !self.messages.isEmpty {
            self.tableView.scrollToRow(at: IndexPath(row: self.messages.count - 1, section: 0), at: .bottom, animated: animated)
        }
    }

    func shouldScrollToBottom() -> Bool {
        return self.tableView.contentOffset.y + self.tableView.frame.height > self.tableView.contentSize.height - 50.0
    }

    func scrollToBottomIfShould() {
        if self.shouldScrollToBottom() {
            self.scrollToBottom(animated: true)
        }
    }

    func appendMessages(_ messages: [SteamChatMessage]) {
        for msg in messages {
            self.messages.append(ParsedMessage(attributed: MessageParser.shared.parseMessage(msg.message), msg: msg))
        }
    }

    func insertMessages(_ messages: [SteamChatMessage]) {
        let paths = messages.enumerated().map { (offset: Int, element: SteamChatMessage) -> IndexPath in
            return IndexPath(row: self.messages.count + offset, section: 0)
        }

        self.appendMessages(messages)
        self.tableView.insertRows(at: paths, with: .automatic)
        self.scrollToBottom(animated: true)
    }

    func empty() {
        self.messages.removeAll()
    }

    func reload() {
        self.tableView.reloadData()
    }
    
    @IBAction func tapAction(_ sender: AnyObject) {
        self.targetPerform(ChatViewController.hideKeyboardActionSelector, sender: sender)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        for path in self.tableView.indexPathsForVisibleRows ?? [] {
            let cell = self.tableView.cellForRow(at: path)!
            let message = self.messages[path.row]
            let textView = cell.viewWithTag(1) as! ChatTextView
            let size = ChatTextView.textBounds(text: message.attributed, width: self.parent!.view.frame.width / 2)
            textView.setFrameTo(size, parent: self.parent!.view.frame)
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.messages.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let width = (self.parent!.view.frame.width / 2)
        return ChatTextView.textBounds(text: self.messages[indexPath.row].attributed, width: width).height + ChatTextView.offset * 2
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = self.messages[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: message.msg.author == self.session.user.id ? "ingoingCell" : "outgoingCell")!
        let textView = cell.viewWithTag(1) as! ChatTextView
        textView.attributedText = message.attributed

        let size = ChatTextView.textBounds(text: message.attributed, width: self.parent!.view.frame.width / 2)
        textView.setFrameTo(size, parent: self.parent!.view.frame)

        return cell
    }

}
