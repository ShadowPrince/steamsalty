//
//  ChatSessionsManager.swift
//  SteamChat
//
//  Created by shdwprince on 10/30/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import Foundation

class ChatSession: NSObject {
    let user: SteamUser
    var messages = [SteamChatMessage]()
    
    init(user: SteamUser) {
        self.user = user
    }
}

protocol ChatSessionManagerDelegate {
    func receivedMessages(_ messages: [SteamChatMessage])
}

class ChatSessionsManager: StackedContainersViewControllerDataSource, SteamPollManagerDelegate {
    static let shared = ChatSessionsManager()

    let queue = OperationQueue()

    var delegates = [Int: ChatSessionManagerDelegate]()
    var sessions = [ChatSession]()
    private var index = 0

    init() {
        SteamPollManager.shared.delegates.append(self)
    }

    func pollReceived(event: SteamEvent, manager: SteamPollManager) {
        switch event.type {
        case .chatMessage:
            let msgEvent = event as! SteamChatMessageEvent
            for (i, session) in self.sessions.enumerated() {
                if session.user.id == event.from {
                    session.messages.append(msgEvent.message)
                    OperationQueue.main.addOperation {
                        self.delegates[i]?.receivedMessages([msgEvent.message])
                    }
                }
            }
        default: break
        }
    }

    func pollError(_ error: Error, manager: SteamPollManager) {

    }

    func openChat(with user: SteamUser) {
        var existingSession: ChatSession?
        for session in self.sessions {
            if session.user == user {
                existingSession = session
            }
        }

        if let existingSession = existingSession {
            self.index = self.sessions.index(of: existingSession)!
        } else {
            let session = ChatSession(user: user)
            self.sessions.append(session)

            let index = self.sessions.isEmpty ? 0 : self.sessions.count - 1
            self.index = index

            self.queue.addOperation {
                SteamApi.shared.chatLog(user: user.id) { messages, error in
                    if let messages = messages {
                        session.messages.append(contentsOf: messages)
                        
                        OperationQueue.main.addOperation {
                            self.delegates[index]?.receivedMessages(messages)
                        }
                    }
                }
            }
        }
    }

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
        self.sessions.remove(at: self.index)
    }
}
