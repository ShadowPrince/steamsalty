//
//  ChatViews.swift
//  SteamChat
//
//  Created by shdwprince on 11/1/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import Foundation
import UIKit


@IBDesignable
class ChatTextView: UITextView {
    static let offset: CGFloat = 4.0
    static let inset: CGFloat = 8.0
    static let combined: CGFloat = offset + inset

    @IBInspectable
    var isIngoing: Bool = true

    static func textBounds(text: NSAttributedString, width: CGFloat) -> CGRect {
        var bounds = (text as NSAttributedString).boundingRect(with: CGSize.init(width: width, height: CGFloat(MAXFLOAT)),
                                                               options: [.usesLineFragmentOrigin, .usesFontLeading],
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
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.textContainerInset = .init(top: ChatTextView.inset, left: ChatTextView.inset, bottom: ChatTextView.inset, right: ChatTextView.inset)
        self.textContainer.lineFragmentPadding = 0.0

        self.layer.cornerRadius = 10.0
        self.layer.borderWidth = 1.5
        self.layer.borderColor = self.tintColor.cgColor
    }
}

@IBDesignable
class NewMessagesLabel: UILabel {
    override func awakeFromNib() {
        super.awakeFromNib()

        self.layer.masksToBounds = true
        self.layer.cornerRadius = self.frame.width / 2
    }
}

@IBDesignable
class AvatarImageView: UIImageView {
    let queue = OperationQueue()

    override func awakeFromNib() {
        super.awakeFromNib()

        self.layer.masksToBounds = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.layer.cornerRadius = self.frame.height / 2
    }

    func loadImage(at url: URL) {
        queue.addOperation {
            let request = URLRequest(url: url)
            do {
                let data = try NSURLConnection.sendSynchronousRequest(request, returning: nil)
                OperationQueue.main.addOperation {
                    self.image = UIImage(data: data)
                }
            } catch let e {
                print(e)
            }
        }
    }
}

class PersonaStateLabel: UILabel {
    func setToState(_ state: SteamPersonaStateEvent.State) {
        switch state {
        case .online:
            self.textColor = UIColor.green
            self.text = "online"
        case .away:
            self.textColor = UIColor.darkGray
            self.text = "away"
        case .offline:
            self.textColor = UIColor.gray
            self.text = "offline"
        default:
            self.textColor = UIColor.black
            self.text = "???"
        }
    }
}
