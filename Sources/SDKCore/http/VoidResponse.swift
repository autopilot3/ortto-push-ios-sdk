//
//  VoidResponse.swift
//
//  Created on 25/5/2026.
//

import Foundation

/// Placeholder `Decodable` for API calls whose response body carries no useful information
/// (e.g. fire-and-forget tracking GETs). The response bytes are discarded.
public struct VoidResponse: Decodable {
    public init() {}
    public init(from decoder: Decoder) throws {}
}
