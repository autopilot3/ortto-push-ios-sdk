//
//  File.swift
//  
//
//  Created by Mitch Flindell on 5/1/2023.
//

import Foundation

struct PushToken: Codable {
    var value: String
    var type: String
    
    public init (
        value: String,
        type: String
    ) {
        self.value = value
        self.type = type 
    }
}
