//
//  File.swift
//  
//
//  Created by Mitch Flindell on 21/6/2023.
//

import Foundation

struct Widget: Codable {
    let id: String
    let type: WidgetType
    let page: Page
    let `where`: Where
    let `when`: When
    let who: Who
    let trigger: Trigger
    let frequency: String
    let expiry: String?
    let isGdpr: Bool
    let style: Style
    let html: String
    let useSlot: String
    let font: [Font]?
    let fontUrls: [String]
    let variables: [String: String]?
    let talkMessageBody: String?
    let talkMessageAgentId: String?
    let talkMessageAgent: TalkMessageAgent?
    let hasRecaptcha: Bool = false

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case type = "type"
        case page = "page"
        case `where` = "where"
        case `when` = "when"
        case who = "who"
        case trigger = "trigger"
        case frequency = "frequency"
        case expiry = "expiry"
        case isGdpr = "is_gdpr"
        case style = "style"
        case html = "html"
        case useSlot = "use_slot"
        case font = "font"
        case fontUrls = "font_urls"
        case variables = "variables"
        case talkMessageBody = "talk_message_body"
        case talkMessageAgentId = "talk_message_agent_id"
        case talkMessageAgent = "talk_message_agent"
        case hasRecaptcha = "has_recaptcha"
    }
}

enum WidgetType: String, Codable {
    case talk = "talk"
    case form = "form"
    case popup = "popup"
    case bar = "bar"
    case notification = "notification"
    case prompt = "prompt"
}

struct Filter: Codable {
    let or: [Properties]?

    enum CodingKeys: String, CodingKey {
        case or = "$or"
    }
}

func decodeFilter<T: CodingKey>(_ container: KeyedDecodingContainer<T>, for key: T) -> [Filter] {
    if let filter = try? container.decodeIfPresent(Filter.self, forKey: key) {
        return [filter]
    }
    
    if let filters = try? container.decodeIfPresent([Filter].self, forKey: key) {
        return filters
    }
    
    return []
}

struct Page: Codable {
    let selection: String
    let filter: [Filter]
    let device: String
    let platforms: [String]?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.selection = try container.decode(String.self, forKey: .selection)
        self.device = try container.decode(String.self, forKey: .device)
        self.platforms = try container.decode([String]?.self, forKey: .platforms)
        self.filter = decodeFilter(container, for: .filter)
    }
}

struct Where: Codable {
    let selection: String
    let filter: [String]?
}

struct When: Codable {
    let selection: String
    let value: String
}

struct Who: Codable {
    let selection: String
    let filter: [Filter]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.selection = try container.decode(String.self, forKey: .selection)
        self.filter = decodeFilter(container, for: .filter)
    }
}

struct Trigger: Codable {
    struct Rules: Codable {
        struct Conditions: Codable {
            let id: String
            let value: String
        }

        let when: String
        let conditions: [Conditions]
    }

    let selection: String
    let rules: Rules?
    let stop: [String]?
    let value: String?
}

struct Style: Codable {
    var headingFont: String?
    var headingFallbackFont: String?
    var headingColor: String?
    var textFont: String?
    var textFallbackFont: String?
    var textColor: String?
    var textSize: Double?
    var textScale: Double?
    var textHeadingSize: Double?
    var textBodySize: Double?
    var backgroundColor: String?
    var backgroundImage: String?
    var backgroundImagePosition: String?
    var backgroundImageLayout: String?
    var backgroundImageOpacity: Double?
    var size: String?
    var position: String?
    var corners: String?
    var buttonColor: String?
    var buttonFill: String?
    var secondaryButtonShape: String?
    var secondaryButtonColor: String?
    var secondaryButtonBorderColor: String?
    var secondaryButtonFill: String?
    var linkColor: String?
    var formFieldTextColor: String?
    var formFieldBorderColor: String?
    var formFieldFillColor: String?
    var overlayColor: String?
    var shadowColor: String?
    var buttonShape: String?
    var buttonBorderColor: String?
    var formFieldShape: String?
    var closeButtonShape: String?
    var closeButtonFill: String?
    var closeButtonStroke: String?
    var sticky: Bool?
    var width: String?
    var closeButton: Bool?
    var wheelNeedleColor: String?
    var wheelBorderColor: String?
    var wheelSlice1Color: String?
    var wheelSlice2Color: String?
    var wheelText1Color: String?
    var wheelText2Color: String?
    var borderColor: String?
    var couponShape: String?
    var couponColor: String?
    var couponBorderColor: String?
    var couponFill: String?
    var floatingButtonOffset: Double?
    var maxWidth: Double?
    var padding: Bool?
    var textLineHeight: Double?
    var headingWeight: Double?
    var headingStyle: String?
    var textStyle: String?
    var textWeight: Double?
}

struct Font: Codable {
    var type: String?
    var url: String?
    var service: String?
}

struct TalkMessageAgent: Codable {
    let id: String
    let status: String
    let name: String
    let avatar: String
}

struct Properties: Codable {
    struct StrIs: Codable {
        let value: String
        let label: String
    }

    struct StrContains: Codable {
        let value: String
        let label: String
    }

    struct StrStarts: Codable {
        let value: String
        let label: String
    }

    let strIs: StrIs?
    let strContains: StrContains?
    let strStarts: StrStarts?

    enum CodingKeys: String, CodingKey {
        case strIs = "$str::is"
        case strContains = "$str::contains"
        case strStarts = "$str::starts"
    }
}

struct WidgetsResponse: Codable {
    let widgets: [Widget]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.widgets = (try? container.decode([Widget].self, forKey: .widgets)) ?? []
    }
    
    init(widgets: [Widget]) {
        self.widgets = widgets
    }
}

struct WebViewConfig: Codable {
    let token: String
    let endpoint: String
    let data: WidgetsResponse
}
