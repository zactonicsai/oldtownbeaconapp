//
//  Item.swift
//  oldtownalabamabeacondemo
//
//  Created by Zachary Lewis on 9/12/25.
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
