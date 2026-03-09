//
//  Item.swift
//  ForMe
//
//  Created by Nur Ahmad Khatim on 09/03/26.
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
