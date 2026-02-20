//
//  Item.swift
//  iDSACompanion
//
//  Created by vonbaussnerns on 2026-02-20.
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
