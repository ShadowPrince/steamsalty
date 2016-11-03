//
//  Helpers.swift
//  SteamChat
//
//  Created by shdwprince on 10/30/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import Foundation
import UIKit

extension Array {
    func randomElement() -> Array.Element {
        let index = Int(arc4random_uniform(UInt32(self.count)))
        return self[index]
    }
}

extension NSRegularExpression {
    static func matches(in string: String, of pattern: String, options: NSRegularExpression.Options) -> [[String]] {
        var result = [[String]]()
        let regex = try! NSRegularExpression(pattern: pattern, options: options)
        for match in regex.matches(in: string, options: [], range: NSRange(location: 0, length: string.characters.count)) {
            var matchStrings = [String]()
            for i in 1..<match.numberOfRanges {
                matchStrings.append((string as NSString).substring(with: match.rangeAt(i)))
            }

            result.append(matchStrings)
        }

        return result
    }
}

extension JSONSerialization {
    static func jsonObject(with string: String, options: JSONSerialization.ReadingOptions) throws -> Any {
        return try JSONSerialization.jsonObject(with: string.data(using: .utf8)!, options: options)
    }
}

class MessageParser {
    static let shared = MessageParser()

    var cache = [String: UIImage]()
    
    func emoteUrl(_ named: String) -> URL {
        return URL(string: "https://steamcommunity-a.akamaihd.net/economy/emoticon/\(named)")!
    }

    func parseMessage(_ msg: String) -> NSAttributedString {
        var attributed = NSMutableAttributedString(string: msg)
        
        for emoteArray in NSRegularExpression.matches(in: msg, of: "(\\ː\\w+?\\ː)", options: []) {
            let emoteCode = emoteArray[0]

            let emoteName = emoteCode.substring(with: emoteCode.index(emoteCode.startIndex, offsetBy: 1)..<emoteCode.index(emoteCode.endIndex, offsetBy: -1))
            if self.cache[emoteName] == nil {
                do {
                    let data = try Data.init(contentsOf: self.emoteUrl(emoteName))
                    self.cache[emoteName] = UIImage(data: data)
                } catch let e {
                    print(e)
                }
            }

            if let image = self.cache[emoteName] {
                let attachment = NSTextAttachment()
                attachment.image = image
                let imageString = NSAttributedString(attachment: attachment)

                let range = (attributed.string as NSString).range(of: emoteCode)
                attributed.replaceCharacters(in: range, with: imageString)
            }
        }

        return attributed
    }
}
