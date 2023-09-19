//
//  File.swift
//  
//
//  Created by Mitch Flindell on 5/1/2023.
//

import Foundation

public struct LinkUtm {
    public var campaign: String?
    public var content: String?
    public var source: String?
    public var medium: String?
    public var term: String?

    public init(_ queryItems: [URLQueryItem]?) {
        queryItems?.forEach({ queryItem in
            switch (queryItem.name) {
            case "utm_campaign":
                self.campaign = queryItem.value
            case "utm_content":
                self.content = queryItem.value
            case "utm_source":
                self.source = queryItem.value
            case "utm_medium":
                self.medium = queryItem.value
            case "utm_term":
                self.term = queryItem.value
            default:
                break;
            }
        })
    }
}
