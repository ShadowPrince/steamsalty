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

    func start() {
        self.queue.addOperation {
            SteamApi.shared.poll { (result, error) in
                if error == nil {
                    print(result!)
                    for event in result!.events {
                        self.delegates.forEach({ (d) in
                            d.pollReceived(event: event, manager: self)
                        })
                    }
                } else {
                    print(error!)
                    self.delegates.forEach({ (d) in
                        d.pollError(error!, manager: self)
                    })
                }

                Thread.sleep(forTimeInterval: 1.0)
                self.start()
            }
        }
    }
}
