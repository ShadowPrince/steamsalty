//
//  SteamPollManager.swift
//  SteamChat
//
//  Created by shdwprince on 10/26/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import Foundation

protocol SteamPollManagerDelegate: AnyObject {
    func pollReceived(events: [SteamEvent], manager: SteamPollManager)
    func pollError(_ error: Error, manager: SteamPollManager)
    func pollStatus(_ user: SteamUser, contacts: [SteamUser], emotes: [SteamEmoteName])
}

class SteamPollManager {
    private let queue = OperationQueue()
    
    static let shared = SteamPollManager()
    var delegates = [SteamPollManagerDelegate]()
    var isRunning = true

    func initialize() throws {
        do {
            try SteamApi.sharedInit()
            SteamApi.shared.status { (user, contacts, emotes, error) in
                if error == nil {
                    self.delegates.forEach { $0.pollStatus(user!, contacts: contacts!, emotes: emotes!) }
                }
            }
        } catch let e {
            self.delegates.forEach {
                $0.pollError(e, manager: self)
            }

            throw e
        }
    }
    
    func start() {
        if SteamApi.shared == nil {
            print("API not initialized")
            return
        }

        if !self.isRunning {
            return
        }
        
        self.queue.addOperation {
            print("pollin...")
            SteamApi.shared.poll { (result, error) in
                var debugThrow: Error? = SteamApi.RequestError.AuthFailed
                debugThrow = nil
                
                if error == nil && debugThrow == nil {
                    for event in result!.events {
                        switch event.type {
                        case .personaState:
                            SteamApi.shared.state(of: event.from) { user, error in
                                if let user = user {
                                    let newEvent = SteamUserUpdateEvent(type: .userUpdate,
                                                                        timestamp: event.timestamp,
                                                                        from: event.from,
                                                                        user: user)
                                    self.delegates.forEach { $0.pollReceived(events: [newEvent], manager: self) }
                                } else {
                                    self.delegates.forEach { $0.pollError(error!, manager: self) }
                                }
                            }
                            
                        default:
                            break
                        }
                    }
                    
                    self.delegates.forEach { $0.pollReceived(events: result!.events, manager: self) }
                    self.start()
                } else {
                    let error = debugThrow != nil ? debugThrow! : error!
                    print(error)
                    
                    if let error = error as? SteamApi.RequestError {
                        switch error {
                        case .PollError(let reason) where reason == "Not Logged On":
                            print("Performing re-initialization due to poll error")
                            do {
                                try self.initialize()
                                self.start()
                            } catch { }
                            return
                        case .PollTimeout:
                            self.start()
                            return
                        default:
                            SteamApi.shared.reset()
                            Thread.sleep(forTimeInterval: 5.0)
                            self.start()
                        }

                        self.delegates.forEach {
                            $0.pollError(error, manager: self)
                        }
                    }
                }
            }
        }
    }
}
