//
//  Item.swift
//  grabber
//
//  Created by Rushi Patel on 27/3/2026.
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
