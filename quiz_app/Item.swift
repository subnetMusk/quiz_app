//
//  Item.swift
//  quiz_app
//
//  Created by Leonardo Soligo on 9/1/25.
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
