//
//  ChatSessionsManager.swift
//  SteamChat
//
//  Created by shdwprince on 10/30/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import Foundation

class ChatSession: NSObject {
    var user: SteamUser
    var messages = [SteamChatMessage]()
    var unread: Int = 0
    
    init(user: SteamUser) {
        self.user = user
    }

    override var description: String {
        return self.user.name
    }
}

protocol ChatSessionManagerDelegate {
    func receivedMessages(_ messages: [SteamChatMessage])
    func updateUserStatus()
    func markedSessionAsRead(_ session: ChatSession)
    func updatedNextElement()
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
            var didRearrange = false
            if let i = self.sessions.index(where: { $0.user.id == event.from }) {
                let session = self.sessions[i]
                session.messages.append(msgEvent.message)
                session.unread += 1
                
                if self.stackIndex != i {
                    if i != self.stackNextIndex {
                        swap(&self.sessions[i], &self.sessions[self.stackNextIndex])
                    }
                    
                    didRearrange = true
                }
                
                OperationQueue.main.addOperation {
                    self.delegates[i]?.receivedMessages([msgEvent.message])
                }
            }

            if didRearrange {
                OperationQueue.main.addOperation {
                    self.delegates.forEach {(_, d) in 
                        d.updatedNextElement()
                    }
                }
            }
        case .personaState:
            if let index = self.sessions.index(where: { $0.user.id == event.from } ) {
                let stateEvent = event as! SteamPersonaStateEvent
                self.sessions[index].user.state = stateEvent.state
                
                OperationQueue.main.addOperation {
                    self.delegates[index]?.updateUserStatus()
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

    func sessionOf(user: SteamUser) -> ChatSession? {
        for session in self.sessions {
            if session.user == user {
                return session
            }
        }

        return nil
    }

    func markAsRead(session: ChatSession) {
        session.unread = 0
        self.delegates[-1]?.markedSessionAsRead(session)
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
        let oldNext = self.stackNextIndex
        self.sessions.remove(at: self.index)

        if oldNext > self.index {
            self.index -= 1
        }
    }
}
