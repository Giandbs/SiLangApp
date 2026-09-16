//
//  Item.swift
//  SiLang
//
//  Created by Gian Denggan Benjamin on 10/09/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
