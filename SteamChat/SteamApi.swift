//
//  SteamAPI.swift
//  SteamChat
//
//  Created by shdwprince on 10/25/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import Foundation
import Alamofire

protocol SteamApiMethod {
    func request(_ tail: String, parameters: Parameters) -> DataRequest
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

class SteamApi {
    enum RequestError: Error {
        case Error(String)
        case PollError(String)
        case PollTimeout
    }

    class WebApi: SteamApiMethod {
        let sessionId: String

        init(_ sessionId: String) {
            self.sessionId = sessionId
        }

        func request(_ tail: String, parameters _parameters: Parameters) -> DataRequest {
            var parameters = _parameters
            parameters["sessionid"] = self.sessionId
            return Alamofire.request("https://steamcommunity.com/".appending(tail), method: .post, parameters: parameters)
        }
    }

    class InternalApi: SteamApiMethod {
        var requestNumber = 0, messageNumber = 0
        let host, key, id: String
        init(_ host: String, key: String, id: String) {
            self.host = host
            self.key = key
            self.id = id
        }

        func request(_ tail: String, parameters _parameters: Parameters) -> DataRequest {
            self.requestNumber += 1

            var parameters = _parameters
            parameters["access_token"] = self.key
            parameters["umqid"] = self.id
            parameters["pollid"] = self.requestNumber
            parameters["message"] = self.messageNumber
            return Alamofire.request(self.host.appending(tail), parameters: parameters)
        }
    }
    
    static var shared: SteamApi!
    static func sharedInit() {
        var web: String?, host: String?, key: String?, umqid: String?

        let request = URLRequest(url: URL(string: "https://steamcommunity.com/chat")!)
        if let data = try? NSURLConnection.sendSynchronousRequest(request, returning: nil), let html = String(data: data, encoding: .utf8) {
            if let sessionId = NSRegularExpression.matches(in: html, of: "g_sessionID = \"(\\S+)\"", options: []).first?.first,
               let apiMatch = NSRegularExpression.matches(in: html, of: "new CWebAPI\\(\\s*\\S+,\\s*'(\\S+)',\\s*\"(\\S+)\"", options: []).first {
                web = sessionId
                host = apiMatch[0]
                key = apiMatch[1]
            }
        }

        if let host = host, let key = key {
            let url = "\(host)ISteamWebUserPresenceOAuth/Logon/v0001/?jsonp=jQuery111105162750359218159_1477598446476&ui_mode=web&access_token=\(key)&_=1477598446477"
            let request = URLRequest(url: URL(string: url)!)
            if let data = try? NSURLConnection.sendSynchronousRequest(request, returning: nil),
               let javascript = String(data: data, encoding: .utf8),
               let match = NSRegularExpression.matches(in: javascript, of: "(\\{.*\\})", options: [.dotMatchesLineSeparators, .anchorsMatchLines]).first {

                do {
                    let jsonObject = try JSONSerialization.jsonObject(with: match[0], options: [])
                    let dict = jsonObject as! Dictionary<String, Any>
                    let errorString = dict["error"] as! String
                    switch errorString {
                    case "OK":
                        umqid = dict["umqid"] as? String
                    default:
                        break
                    }
                } catch { }
            }
                
            if let web = web, let umqid = umqid {
                shared = SteamApi(
                    web: WebApi(web),
                    internal: InternalApi(host, key: key, id: umqid)
                )
            } else {
                print("failure")
            }
        }
    }

    let web: SteamApiMethod
    let api: SteamApiMethod

    init(web: SteamApiMethod, internal api: SteamApiMethod) {
        self.web = web
        self.api = api
    }

    func status(handler: @escaping (SteamUser?, [SteamUser]?, Error?) -> ()) {
        Alamofire.request("https://steamcommunity.com/chat").responseString { (response) in
            var error: Error = RequestError.Error("Request failed")

            let html = response.result.value!
            if let match = NSRegularExpression.matches(in: html, of: " WebAPI, (\\{.*?\\}), (\\[.*?\\])", options: []).first {
                let selfJson = match[0]
                let usersJson = match[1]
                do {
                    let selfObject = try JSONSerialization.jsonObject(with: selfJson, options: [])
                    let friendsObject = try JSONSerialization.jsonObject(with: usersJson, options: [])
                    
                    let selfUser = try SteamUser.decode(selfObject)
                    let friendsArray = try [SteamUser].decode(friendsObject)
                    
                    handler(selfUser, friendsArray, nil)
                    return
                } catch let e {
                    error = e
                }
            }
            
            handler(nil, nil, error);
        }
    }

    func poll(handler: @escaping (SteamPollResponse?, Error?) -> ()) {
        let parameters: [String: Any] = ["jsonp": "",
                                          "sectimeout": 35,
                                          "secidletime": 20,
                                          "use_accountids": 1,
                                          "_": UInt64(Date().timeIntervalSince1970), ]

        self.api.request("ISteamWebUserPresenceOAuth/Poll/v0001/", parameters: parameters).responseString { response in
            var error: Error = RequestError.Error("Request failed")

            if let javascript = response.result.value,
               let match = NSRegularExpression.matches(in: javascript, of: "(\\{.*\\})", options: [.dotMatchesLineSeparators, .anchorsMatchLines]).first {
                do {
                    let jsonObject = try JSONSerialization.jsonObject(with: match[0], options: [])
                    let dict = jsonObject as! Dictionary<String, Any>
                    let errorString = dict["error"] as! String

                    switch errorString {
                    case "OK":
                        handler(try SteamPollResponse.decode(jsonObject), nil)
                        return
                    case "Timeout":
                        error = RequestError.PollTimeout
                    default:
                        error = RequestError.PollError(errorString)
                    }
                } catch let e {
                    error = e
                }
            }

            handler(nil, error)
        }
    }

    func chatLog(user identifier: SteamUserId, handler: @escaping ([SteamChatMessage]?, Error?) -> ()) {
        self.web.request("chat/chatlog/\(identifier)", parameters: [:]).responseJSON { response in
            do {
                handler(try [SteamChatMessage].decode(response.result.value), nil)
            } catch let e {
                handler(nil, e)
            }
        }
    }
}
