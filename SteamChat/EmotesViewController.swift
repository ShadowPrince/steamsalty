//
//  EmotesViewController.swift
//  SteamChat
//
//  Created by shdwprince on 11/7/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import Foundation
import UIKit

class EmotesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    let queue = OperationQueue()

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return ChatSessionsManager.shared.emotes.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath)
        let emoji = ChatSessionsManager.shared.emotes[indexPath.row]
        let view = cell.viewWithTag(1) as! UIImageView
        if let image = MessageParser.shared.cachedEmote(named: emoji) {
            view.image = image
        } else {
            self.queue.addOperation {
                if let image = MessageParser.shared.loadEmote(named: emoji) {
                    OperationQueue.main.addOperation {
                        view.image = image
                    }
                }
            }
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let emoteName = ChatSessionsManager.shared.emotes[indexPath.row]
        self.targetPerform(ChatViewController.sayTextAppendActionSelector, sender: (emoteName as NSString))
    }
}
