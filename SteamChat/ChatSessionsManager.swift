//
//  ChatSessionsManager.swift
//  SteamChat
//
//  Created by shdwprince on 10/30/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import Foundation
import UIKit

protocol ChatSessionsManagerDelegate {
    func sessionOpenedExisting(_ session: ChatSessionsManager.Session, from: ChatSessionsManager)
    func sessionReceivedMessages(_ messages: [SteamChatMessage], in session: ChatSessionsManager.Session, from: ChatSessionsManager)
    func sessionMarkedAsRead(_ session: ChatSessionsManager.Session, from: ChatSessionsManager)
    func sessionUpdatedStatus(_ session: ChatSessionsManager.Session, from: ChatSessionsManager)
    func sessionUpdatedNext(at index: Int, from: ChatSessionsManager)
}

extension Array where Element: ChatSessionsManager.Session {
    subscript (user: SteamUser) -> Element? {
        return self.first(where: { $0.user == user } )
    }

    subscript (userid: SteamUserId) -> Element? {
        return self.first(where: { $0.user.id == userid })
    }
}

class ChatSessionsManager: StackedContainersViewControllerDataSource, SteamPollManagerDelegate, SettingsDelegate {
    class Session: NSObject {
        var user: SteamUser
        var messages = [SteamChatMessage]()
        var unread: Int = 0
        var typingUntil: Date = Date()
        
        init(user: SteamUser) {
            self.user = user
        }
        
        override var description: String {
            return self.user.name
        }
    }

    static let shared = ChatSessionsManager()

    let typingInterval: CFTimeInterval = 8.0

    let queue = OperationQueue()
    var delegates = [Int: ChatSessionsManagerDelegate]()
    var sessions = [Session]()

    var contacts = [SteamUser]()
    var emotes = [SteamEmoteName]()
    var user: SteamUser!

    private var index = 0
    private var lastTypingNotificationDate = Date()

    init() {
        SteamPollManager.shared.delegates.append(self)
        Settings.shared.delegates.append(self)

        if Settings.shared.pushNotifications() {
            self.enablePushNotifications()
        }
    }

    // polling
    func pollReceived(events: [SteamEvent], manager: SteamPollManager) {
        var didRearrange = false

        for event in events {
            switch event.type {
            case .chatMessage:
                let msgEvent = event as! SteamChatMessageEvent

                if Settings.shared.pushNotifications() {
                    self.sendPushNotification(event: msgEvent)
                }

                var _i = self.sessions.index(where: { $0.user.id == event.from })
                if _i == nil {
                    if let user = self.contacts.first(where: { $0.id == event.from }) {
                        _i = self.sessions.count
                        self.sessions.append(ChatSessionsManager.Session(user: user))
                    }
                }
                
                if let i = _i {
                    let session = self.sessions[i]
                    session.messages.append(msgEvent.message)
                    session.unread += 1
                    session.typingUntil = Date()
                    
                    if self.stackIndex != i {
                        if i != self.stackNextIndex {
                            swap(&self.sessions[i], &self.sessions[self.stackNextIndex])
                        }
                        
                        didRearrange = true
                    }
                    
                    OperationQueue.main.addOperation {
                        self.delegates[i]?.sessionReceivedMessages([msgEvent.message], in: session, from: self)
                        self.delegates[-1]?.sessionReceivedMessages([msgEvent.message], in: session, from: self)
                    }
                }
            case .typing:
                if let index = self.sessions.index(where: { $0.user.id == event.from } ) {
                    let session = self.sessions[index]
                    
                    session.typingUntil = Date().addingTimeInterval(self.typingInterval)
                    OperationQueue.main.addOperation {
                        self.delegates[index]?.sessionUpdatedStatus(session, from: self)
                    }
                }
            case .userUpdate:
                if let index = self.sessions.index(where: { $0.user.id == event.from } ) {
                    let updateEvent = event as! SteamUserUpdateEvent
                    let session = self.sessions[index]

                    session.user = updateEvent.user
                    
                    OperationQueue.main.addOperation {
                        self.delegates[index]?.sessionUpdatedStatus(session, from: self)
                    }
                }
            default: break
            }
        }

        if didRearrange {
            OperationQueue.main.addOperation {
                self.delegates.forEach { $0.value.sessionUpdatedNext(at: self.stackNextIndex, from: self) }
            }
        }
    }

    func pollStatus(_ user: SteamUser, contacts: [SteamUser], emotes: [String]) {
        self.user = user
        self.contacts = contacts
        self.emotes = emotes
    }

    func pollError(_ error: Error, manager: SteamPollManager) {
        switch error {
        case SteamApi.RequestError.AuthFailed:
            break
            //self.sessions.removeAll()
        default:
            break
        }
    }

    // helpers
    func openChat(with user: SteamUser) {
        if let existingSession = self.sessions[user] {
            self.index = self.sessions.index(of: existingSession)!
        } else {
            let session = ChatSessionsManager.Session(user: user)
            session.unread = user.unreadMessages
            self.sessions.append(session)

            let index = self.sessions.isEmpty ? 0 : self.sessions.count - 1
            self.index = index

            self.queue.addOperation {
                SteamApi.shared.chatLog(user: user.id) { messages, error in
                    if let messages = messages {
                        session.messages.append(contentsOf: messages)
                        
                        OperationQueue.main.addOperation {
                            self.delegates[index]?.sessionReceivedMessages(messages, in: session, from: self)
                        }
                    }
                }
            }
        }
    }

    func typingNotify(session: Session) {
        if self.lastTypingNotificationDate.timeIntervalSinceNow < -self.typingInterval {
            self.lastTypingNotificationDate = Date()
            SteamApi.shared.chatType(to: session.user.cid, handler: nil)
        }
    }

    func markAsRead(session: ChatSessionsManager.Session) {
        session.unread = 0
        let index = self.sessions.index(of: session)!
        self.delegates[index]?.sessionMarkedAsRead(session, from: self)
        self.delegates[-1]?.sessionMarkedAsRead(session, from: self)
    }

    func sendPushNotification(event: SteamChatMessageEvent) {
        let notification = UILocalNotification()
        notification.alertAction = "New message"
        notification.alertTitle = self.contacts.first(where: { $0.id == event.from })?.name ?? "Unknown"
        notification.alertBody = event.message.message
        notification.timeZone = NSTimeZone.local
        notification.fireDate = Date(timeIntervalSinceNow: 1.0)
        notification.userInfo = ["userid": NSNumber.init(value: event.from), ]

        UIApplication.shared.scheduleLocalNotification(notification)
    }

    func enablePushNotifications() {
        UIApplication.shared.registerUserNotificationSettings(UIUserNotificationSettings(types: [.badge, .sound, .alert], categories: nil))
    }

    func didChangeSetting(_ key: Settings.Keys, to value: Any) {
        if key == .pushNotifications && value as? Bool == true {
            self.enablePushNotifications()
        }
    }

    // stack
    var stackIndex: Int {
        return self.index
    }

    var stackNextIndex: Int {
        return self.index + 1 >= self.sessions.count ? 0 : self.index + 1
    }

    var stackCount: Int {
        return self.sessions.count
    }

    func stackPush() {
        self.index = self.index + 1 >= self.sessions.count ? 0 : self.index + 1
    }

    func stackDrop() {
        let oldNext = self.stackNextIndex
        self.sessions.remove(at: self.index)

        if oldNext > self.index {
            self.index -= 1
        }
    }
}
