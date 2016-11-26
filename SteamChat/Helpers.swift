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

extension UIColor {
    convenience init(rgb: Int, alpha: CGFloat = 1.0) {
        let r = CGFloat((rgb & 0xff0000) >> 16) / 255
        let g = CGFloat((rgb & 0x00ff00) >>  8) / 255
        let b = CGFloat((rgb & 0x0000ff)      ) / 255

        self.init(red: r, green: g, blue: b, alpha: alpha)
    }

    func rgbString() -> String {
        var r, g, b: CGFloat
        r = 0.0
        g = 0.0
        b = 0.0
        self.getRed(&r, green: &g, blue: &b, alpha: nil)

        return String(format: "%02X%02X%02X", r * 255, g * 255, b * 255)
    }
}

extension UIViewController {
    func presentError(_ error: Any) {
        let alert = UIAlertController(title: "Error:", message: String(describing: error), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Close", style: .cancel, handler: { _ in alert.dismiss(animated: true, completion: nil) }))
        self.present(alert, animated: true, completion: nil)
    }

    func targetPerform(_ sel: Selector, sender: AnyObject) {
        if let target = self.target(forAction: sel, withSender: sender) as? UIResponder {
            target.perform(sel, with: sender)
        }
    }
}

extension UIViewController {
    func forcePopover(segue: UIStoryboardSegue) {
        segue.destination.modalPresentationStyle = .popover
        segue.destination.popoverPresentationController?.delegate = PopoverStyleDelegate.shared

        if #available(iOS 9.0, *) {
            if let popOver = segue.destination.popoverPresentationController,
               let anchor  = popOver.sourceView,
               popOver.sourceRect == CGRect() {
                popOver.sourceRect = anchor.bounds
            }
        }
    }

    func presentBlurredOverlay(titled: String, indicator: UIActivityIndicatorView) {
        let view = ILTranslucentView(frame: self.view.bounds)

        let indicatorSize: CGFloat = 20.0
        indicator.frame = CGRect(x: view.bounds.width / 2 - indicatorSize / 2,
                                 y: view.bounds.height / 2 - indicatorSize / 2,
                                 width: indicatorSize,
                                 height: indicatorSize)

        let label = UILabel(frame: CGRect(x: 0,
                                          y: view.bounds.height / 2 + indicatorSize,
                                          width: view.bounds.width,
                                          height: UIFont.systemFontSize * 2))
        label.textAlignment = .center
        label.text = titled

        view.addSubview(label)
        view.addSubview(indicator)

        self.view.addSubview(view)
    }

    func dismissBlurredOverlay() {
        self.view.subviews.last?.removeFromSuperview()
    }
}

class OverlayLoadingView: ILTranslucentView {

}

extension UIWebView {
    func loadBackgroundColor(_ color: UIColor) {
        self.loadHTMLString("<html><body bgcolor=\"#\(color.rgbString())\"></body></html>", baseURL: nil)
        self.isOpaque = false
    }
}

private var backgroundQueue: OperationQueue?

extension OperationQueue {
    static var background: OperationQueue {
        if backgroundQueue == nil {
            backgroundQueue = OperationQueue()
            // magic number, hurray!
            backgroundQueue?.maxConcurrentOperationCount = 20
        }

        return backgroundQueue!
    }

    func addAsyncDoTry(_ closure: @escaping () throws -> Void, success: @escaping () -> Void, exception: @escaping (Error) -> Void) {
        self.addOperation {
            do {
                try closure()
                OperationQueue.main.addOperation {
                    success()
                }
            } catch let e {
                OperationQueue.main.addOperation {
                    exception(e)
                }
            }
        }
    }

    func addAsyncIfElse(_ closure: @escaping () -> Bool, then: @escaping () -> Void, `else`: @escaping () -> Void) {
        self.addOperation {
            if closure() {
                OperationQueue.main.addOperation {
                    then()
                }
            } else {
                OperationQueue.main.addOperation {
                    `else`()
                }
            }
        }
    }

    func addAsync(_ closure: @escaping () -> Void, after: @escaping () -> Void) {
        self.addOperation {
            closure()
            OperationQueue.main.addOperation {
                after()
            }
        }
    }
}

class UniversalActivity: UIActivity {
    private var _activityTitle: String?
    override var activityTitle: String? {
        get {
            return self._activityTitle
        }

        set {
            self._activityTitle = newValue
        }
    }

    private var _activityImage: UIImage?
    override var activityImage: UIImage? {
        get {
            return _activityImage
        }

        set {
            self._activityImage = newValue
        }
    }

    var canPerformHandler: (Any) -> (Bool) = { _ in return true }
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        for item in activityItems {
            if self.canPerformHandler(item) {
                return true
            }
        }

        return false
    }

    var performHandler: () -> () = {}
    override func perform() {
        self.performHandler()
    }

    static func instanceTitled(_ titled: String, icon: UIImage?, handler: @escaping () -> ()) -> UIActivity {
        let instance = UniversalActivity()
        instance.activityTitle = titled
        instance.activityImage = icon
        instance.performHandler = handler

        return instance
    }
}

class PopoverStyleDelegate: NSObject, UIPopoverPresentationControllerDelegate {
    static let shared = PopoverStyleDelegate()
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}

class MessageParser {
    static let shared = MessageParser()

    var cache = [String: Any]()
    
    func emoteUrl(_ named: SteamEmoteName) -> URL {
        return URL(string: "https://steamcommunity-a.akamaihd.net/economy/emoticon/\(named)")!
    }

    func loadEmote(named emoteName: SteamEmoteName) -> UIImage? {
        if self.cache[emoteName] == nil {
            do {
                let data = try NSURLConnection.sendSynchronousRequest(URLRequest(url: self.emoteUrl(emoteName)), returning: nil)
                self.cache[emoteName] = UIImage(data: data)
            } catch let e {
                print(e)
                self.cache[emoteName] = e
            }
        }
        
        return self.cache[emoteName] as? UIImage
    }

    func cachedEmote(named: SteamEmoteName) -> UIImage? {
        return self.cache[named] as? UIImage
    }

    func parseMessage(_ msg: String) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: msg)
        
        for emoteArray in NSRegularExpression.matches(in: msg, of: "([ː:]\\w+?[ː:])", options: []) {
            let emoteCode = emoteArray[0]

            let emoteName = emoteCode.substring(with: emoteCode.index(emoteCode.startIndex, offsetBy: 1)..<emoteCode.index(emoteCode.endIndex, offsetBy: -1))
            if let image = self.loadEmote(named: emoteName) {
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
