//
//  PushToken.swift
//
//
//  Created by Mitch Flindell on 5/1/2023.
//

import Foundation

public struct PushToken: Codable, Equatable {
    public var value: String
    public var type: String

    public init(value: String, type: String) {
        self.value = value
        self.type = type
    }
}
