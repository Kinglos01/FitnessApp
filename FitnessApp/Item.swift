//
//  Item.swift
//  FitnessApp
//
//  Created by Carlos Berio on 2/11/26.
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
