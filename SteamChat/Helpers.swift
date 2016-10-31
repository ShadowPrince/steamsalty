//
//  Helpers.swift
//  SteamChat
//
//  Created by shdwprince on 10/30/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import Foundation

extension Array {
    func randomElement() -> Array.Element {
        let index = Int(arc4random_uniform(UInt32(self.count)))
        return self[index]
    }
}
