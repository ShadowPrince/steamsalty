//
//  SteamAPI.swift
//  SteamChat
//
//  Created by shdwprince on 10/25/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import Foundation
import Alamofire
import Decodable

protocol SteamApiMethod {
    func request(_ tail: String, parameters: Parameters) -> DataRequest
    func reset()
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

        func reset() { }
    }

    class InternalApi: SteamApiMethod {
        var requestNumber = 0, messageNumber = 0
        let host, key, id: String
        init(_ host: String, key: String, id: String, message: Int) {
            self.host = host
            self.key = key
            self.id = id
            self.messageNumber = message
        }

        func request(_ tail: String, parameters _parameters: Parameters) -> DataRequest {
            self.requestNumber += 1

            var parameters = _parameters
            parameters["access_token"] = self.key
            parameters["umqid"] = self.id
            parameters["pollid"] = self.requestNumber
            parameters["message"] = self.messageNumber
            parameters["jsonp"] = ""
            parameters["sectimeout"] = 35

            return Alamofire.request(self.host.appending(tail), parameters: parameters)
        }

        func parse(response: DataResponse<String>) throws -> Dictionary<String, Any> {
            if let javascript = response.result.value,
                let match = NSRegularExpression.matches(in: javascript, of: "(\\{.*\\})", options: [.dotMatchesLineSeparators, .anchorsMatchLines]).first {
                let jsonObject = try JSONSerialization.jsonObject(with: match[0], options: [])
                return jsonObject as! Dictionary<String, Any>
            } else {
                throw RequestError.Error(response.result.value ?? "Request failed")
            }
        }

        func reset() {
            self.requestNumber = 0
            self.messageNumber = 0
        }
    }

    static var shared: SteamApi!
    static func sharedInit() throws {
        do {
            var web: String?, host: String?, key: String?, umqid: String?, message: Int?
            
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
                        message = (dict["message"] as? Int) ?? 0
                    default:
                        break
                    }
                }
                
                if let web = web, let umqid = umqid, let message = message {
                    shared = SteamApi(
                        web: WebApi(web),
                        internal: InternalApi(host, key: key, id: umqid, message: message)
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

    func reset() {
        self.api.reset()
        self.web.reset()
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
        self.api.request("ISteamWebUserPresenceOAuth/Poll/v0001/", parameters: ["use_accountids": 1, ]).responseString (queue: self.queue, encoding: .utf8) { response in
            do {
                let dict = try self.api.parse(response: response)
                let errorString = dict["error"] as! String

                switch errorString {
                case "OK":
                    self.api.messageNumber = (dict["messagelast"] as? Int) ?? self.api.messageNumber
                    handler(try SteamPollResponse.decode(dict), nil)
                    return
                case "Timeout":
                    throw RequestError.PollTimeout
                default:
                    throw RequestError.PollError(errorString)
                }
            } catch let e where e is DecodingError {
                handler(nil, e)
            } catch let e {
                handler(nil, e)
            }
        }
    }

    func state(of contact: SteamUserId, handler: @escaping (SteamUser?, Error?) -> ()) {
        self.web.request("chat/friendstate/\(contact)", parameters: [:]).responseJSON(queue: self.queue, options: []) { response in
            do {
                handler(try SteamUser.decode(response.result.value), nil)
            } catch let e {
                handler(nil, e)
            }
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

    func chatSay(_ text: String, to user: SteamCommunityId, handler: @escaping (Error?) -> ()) {
        self.api
            .request("ISteamWebUserPresenceOAuth/Message/v0001/",
                     parameters: ["type": "saytext",
                                  "steamid_dst": user,
                                  "text": text, ])
            .responseString { response in
                do {
                    let dict = try self.api.parse(response: response)
                    let errorString = dict["error"] as! String
                    switch errorString {
                        case "OK":
                        self.api.messageNumber += 1
                        handler(nil)
                        return
                    default:
                        throw RequestError.Error(errorString)
                    }
                } catch let e {
                    handler(e)
                }
        }
    }
}
