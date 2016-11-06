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

class SteamApi {
    enum RequestError: Error {
        case Error(String)
        case AuthFailed
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
        var requestNumber = 0, messageNumber = 49
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
    static func sharedInit() throws {
        do {
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
                    let jsonObject = try JSONSerialization.jsonObject(with: match[0], options: [])
                    let dict = jsonObject as! Dictionary<String, Any>
                    let errorString = dict["error"] as! String
                    switch errorString {
                    case "OK":
                        umqid = dict["umqid"] as? String
                    default:
                        break
                    }
                }
                
                if let web = web, let umqid = umqid {
                    shared = SteamApi(
                        web: WebApi(web),
                        internal: InternalApi(host, key: key, id: umqid)
                    )
                    
                    return
                }
            }
            
            throw RequestError.AuthFailed
        } catch {
            throw RequestError.AuthFailed
        }
    }

    let queue = DispatchQueue(label: "net.shdwprince.SteamApiWorker")
    let web: SteamApiMethod
    let api: InternalApi

    init(web: SteamApiMethod, internal api: InternalApi) {
        self.web = web
        self.api = api
    }

    func status(handler: @escaping (SteamUser?, [SteamUser]?, [SteamEmoteName]?, Error?) -> ()) {
        Alamofire.request("https://steamcommunity.com/chat").responseString (queue: self.queue, encoding: .utf8) { (response) in
            var error: Error = RequestError.Error("Request failed")
            
            if let html = response.result.value,
               let statusMatch = NSRegularExpression.matches(in: html, of: " WebAPI, (\\{.*?\\}), (\\[.*?\\])", options: []).first,
               let emotesMatch = NSRegularExpression.matches(in: html, of: "SetOwnedEmoticons\\( (.*?) \\);", options: []).first {
                let selfJson = statusMatch[0]
                let usersJson = statusMatch[1]
                let emotesJson = emotesMatch[0]
                do {
                    let selfObject = try JSONSerialization.jsonObject(with: selfJson, options: [])
                    let friendsObject = try JSONSerialization.jsonObject(with: usersJson, options: [])
                    let emotesObject = try JSONSerialization.jsonObject(with: emotesJson, options: [])

                    let selfUser = try SteamUser.decode(selfObject)
                    let friendsArray = try [SteamUser].decode(friendsObject)
                    let emotesArray = try [SteamEmoteName].decode(emotesObject)

                    handler(selfUser, friendsArray, emotesArray, nil)
                    return
                } catch let e {
                    error = e
                }
            }
            
            handler(nil, nil, nil, error);
        }
    }

    func poll(handler: @escaping (SteamPollResponse?, Error?) -> ()) {
        let parameters: [String: Any] = ["jsonp": "",
                                          "sectimeout": 35,
                                          "secidletime": 20,
                                          "use_accountids": 1,
                                          "_": UInt64(Date().timeIntervalSince1970), ]

        self.api.request("ISteamWebUserPresenceOAuth/Poll/v0001/", parameters: parameters).responseString (queue: self.queue, encoding: .utf8) { response in
            var error: Error = RequestError.Error("Request failed")

            if let javascript = response.result.value,
               let match = NSRegularExpression.matches(in: javascript, of: "(\\{.*\\})", options: [.dotMatchesLineSeparators, .anchorsMatchLines]).first {
                do {
                    let jsonObject = try JSONSerialization.jsonObject(with: match[0], options: [])
                    let dict = jsonObject as! Dictionary<String, Any>
                    let errorString = dict["error"] as! String

                    switch errorString {
                    case "OK":
                        self.api.messageNumber += 1
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
        self.web.request("chat/chatlog/\(identifier)", parameters: [:]).responseJSON (queue: self.queue, options: []) { response in
            do {
                handler(try [SteamChatMessage].decode(response.result.value), nil)
            } catch let e {
                handler(nil, e)
            }
        }
    }
}
