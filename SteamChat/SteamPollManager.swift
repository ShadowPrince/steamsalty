//
//  SteamPollManager.swift
//  SteamChat
//
//  Created by shdwprince on 10/26/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import Foundation

protocol SteamPollManagerDelegate {
    func pollReceived(event: SteamEvent, manager: SteamPollManager)
    func pollError(_ error: Error, manager: SteamPollManager)
}

class SteamPollManager {
    private let queue = OperationQueue()
    
    static let shared = SteamPollManager()
    var delegates = [SteamPollManagerDelegate]()

    func initialize() {
        do {
            try SteamApi.sharedInit()
        } catch let e {
            self.delegates.forEach {
                $0.pollError(e, manager: self)
            }
        }
    }
    
    func start() {
        self.queue.addOperation {
            print("Pollin")
            SteamApi.shared.poll { (result, error) in
                if error == nil {
                    print(result!)
                    for event in result!.events {
                        self.delegates.forEach({ (d) in
                            d.pollReceived(event: event, manager: self)
                        })
                    }

                    self.start()
                } else if let error = error {
                    print(error)
                    
                    if let error = error as? SteamApi.RequestError {
                        switch error {
                        case .PollError(let reason) where reason == "Not Logged On":
                            print("Performing re-initialization due to poll error")
                            self.initialize()
                            self.start()
                            return
                        case .PollTimeout:
                            self.start()
                            return
                        default:
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
