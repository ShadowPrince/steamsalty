//
//  SteamDataTypes.swift
//  SteamChat
//
//  Created by shdwprince on 10/25/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import Foundation
import Decodable

typealias SteamUserId = UInt64
typealias SteamCommunityId = String
typealias SteamGameId = String
typealias SteamEmoteName = String

struct SteamPollResponse {
    let timestamp: UInt64
    let events: [SteamEvent]
}

extension SteamPollResponse: Decodable {
    static func decode(_ j: Any) throws -> SteamPollResponse {
        return try SteamPollResponse(timestamp: j => "utc_timestamp",
                                 events: try NSArray.decode(j => "messages").map {
                                    let json = $0 as! Dictionary<String, Any>
                                    let timestamp = try UInt64.decode(json["utc_timestamp"])
                                    let from = (try? SteamUserId.decode(json["accountid_from"])) ?? 0

                                    if let type = try SteamEvent.EventType(rawValue: json => "type") {
                                        switch type {
                                        case .chatMessage:
                                            return SteamChatMessageEvent(type: type, timestamp: timestamp, from: from, message: SteamChatMessage(author: from, message: try json => "text", timestamp: timestamp))
                                        case .personaState:
                                            if let personaState = try json =>? "persona_state" as? Int {
                                                return SteamPersonaStateEvent(type: type, timestamp: timestamp, from: from, state: SteamPersonaStateEvent.State(rawValue: personaState) ?? .unknown)
                                            } else {
                                                fallthrough
                                            }
                                        default:
                                            return SteamEvent(type: type, timestamp: timestamp, from: from)
                                        }
                                    } else {
                                        return SteamEvent(type: .unknown, timestamp: timestamp, from: from)
                                    }
            })
    }
}

class SteamEvent {
    enum EventType: String {
        case personaState = "personastate"
        case chatMessage = "saytext"
        case typing = "typing"
        case userUpdate = "__internal_userUpdate"
        case unknown
    }

    let type: EventType
    let timestamp: UInt64
    let from: SteamUserId

    init(type: EventType, timestamp: UInt64, from: SteamUserId) {
        self.type = type
        self.timestamp = timestamp
        self.from = from
    }
}

class SteamPersonaStateEvent: SteamEvent {
    enum State: Int {
        case offline = 0
        case online = 1
        case busy = 2
        case away = 3
        case snooze = 4
        case unknown = -1
    }

    let state: State

    required init(type: EventType, timestamp: UInt64, from: SteamUserId, state: State) {
        self.state = state
        super.init(type: type, timestamp: timestamp, from: from)
    }
}

class SteamUserUpdateEvent: SteamEvent {
    let user: SteamUser

    required init(type: EventType, timestamp: UInt64, from: SteamUserId, user: SteamUser) {
        self.user = user
        super.init(type: type, timestamp: timestamp, from: from)
    }
}

class SteamChatMessageEvent: SteamEvent {
    let message: SteamChatMessage
    
    required init(type: EventType, timestamp: UInt64, from: SteamUserId, message: SteamChatMessage) {
        self.message = message
        super.init(type: type, timestamp: timestamp, from: from)
    }
}

struct SteamChatMessage {
    let author: SteamUserId
    let message: String
    var timestamp: UInt64

    var date: Date {
        get {
            return Date.init(timeIntervalSince1970: TimeInterval(self.timestamp))
        }

        set {
            self.timestamp = UInt64(newValue.timeIntervalSince1970)
        }
    }
}

extension SteamChatMessage: Decodable {
    static func decode(_ j: Any) throws -> SteamChatMessage {
        return try SteamChatMessage(author: j => "m_unAccountID",
                                    message: j => "m_strMessage",
                                    timestamp: j => "m_tsTimestamp")
    }
}

struct SteamGame {
    let id: SteamGameId?
    let name: String
}

extension SteamGame: Decodable {
    static func decode(_ j: Any) throws -> SteamGame {
        return try SteamGame(id: j =>? "m_nInGameAppID", name: j => "m_strInGameName")
    }
}

struct SteamUser: Equatable {
    let id: SteamUserId
    let cid: SteamCommunityId

    var name: String
    let avatarHash: String
    var unreadMessages: Int

    var lastMessageTimestamp: UInt64
    var state: SteamPersonaStateEvent.State
    var currentGame: SteamGame?

    var avatar: URL {
        let prefix = avatarHash.substring(to: avatarHash.index(avatarHash.startIndex, offsetBy: 2))
        return URL.init(string: "https://steamcdn-a.akamaihd.net/steamcommunity/public/images/avatars/\(prefix)/\(avatarHash)_medium.jpg")!
    }

    var fullAvatar: URL {
        let prefix = avatarHash.substring(to: avatarHash.index(avatarHash.startIndex, offsetBy: 2))
        return URL.init(string: "https://steamcdn-a.akamaihd.net/steamcommunity/public/images/avatars/\(prefix)/\(avatarHash)_full.jpg")!
    }

    var communityProfile: URL {
        return URL.init(string: "https://steamcommunity.com/profiles/\(self.cid)")!
    }

    var lastMessageDate: Date {
        return Date.init(timeIntervalSince1970: Double(self.lastMessageTimestamp))
    }

    public static func ==(lhs: SteamUser, rhs: SteamUser) -> Bool {
        return lhs.id == rhs.id
    }
}

extension SteamUser: Decodable {
    static func decode(_ j: Any) throws -> SteamUser {
        let name: String = try j => "m_strName"
        // screenshot mode
        //name = ["David", "Roger", "Richard", "Syd", "Nick", "Freddie", "Brian", "John", "Trent", "Robert", "Tony", "Pat", "Jakko", "Jim", "Ray", "Robby", "John", ].randomElement()

        return try SteamUser(id: j => "m_unAccountID",
                             cid: j => "m_ulSteamID",
                             name: name,
                             avatarHash: j => "m_strAvatarHash",
                             unreadMessages: j =>? "m_cUnreadMessages" ?? 0,
                             lastMessageTimestamp: j => "m_tsLastMessage",
                             state: SteamPersonaStateEvent.State(rawValue: j => "m_ePersonaState") ?? .unknown,
                             currentGame: (j =>? "m_bInGame" == true) ? SteamGame.decode(j) : nil)
                             
    }
}
