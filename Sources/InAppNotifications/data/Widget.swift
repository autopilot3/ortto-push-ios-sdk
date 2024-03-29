//
//  Widget.swift
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
    let when: When
    let who: Who
    let trigger: Trigger
    let frequency: String
    let expiry: Date?
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
        case id
        case type
        case page
        case `where`
        case when
        case who
        case trigger
        case frequency
        case expiry
        case isGdpr = "is_gdpr"
        case style
        case html
        case useSlot = "use_slot"
        case font
        case fontUrls = "font_urls"
        case variables
        case talkMessageBody = "talk_message_body"
        case talkMessageAgentId = "talk_message_agent_id"
        case talkMessageAgent = "talk_message_agent"
        case hasRecaptcha = "has_recaptcha"
    }
}

enum WidgetType: String, Codable {
    case talk
    case form
    case popup
    case bar
    case notification
    case prompt
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

        selection = try container.decode(String.self, forKey: .selection)
        device = try container.decode(String.self, forKey: .device)
        platforms = try container.decode([String]?.self, forKey: .platforms)
        filter = decodeFilter(container, for: .filter)
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
        selection = try container.decode(String.self, forKey: .selection)
        filter = decodeFilter(container, for: .filter)
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
    let hasLogo: Bool
    let enabledGdpr: Bool
    let recaptchaSiteKey: String?
    let countryCode: String
    let serviceWorkerUrl: String?
    let cdnUrl: String
    var expiry: Double = (Date().addingTimeInterval(86400).timeIntervalSince1970 * 1000)
    let sessionId: String?

    static let `default`: WidgetsResponse = .init(
        widgets: [],
        hasLogo: false,
        enabledGdpr: false,
        recaptchaSiteKey: "",
        countryCode: "",
        serviceWorkerUrl: "",
        cdnUrl: "",
        sessionId: nil
    )

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        widgets = (try? container.decode([Widget].self, forKey: .widgets)) ?? []
        hasLogo = try container.decode(Bool.self, forKey: .hasLogo)
        enabledGdpr = try container.decode(Bool.self, forKey: .enabledGdpr)
        recaptchaSiteKey = try? container.decode(String?.self, forKey: .recaptchaSiteKey)
        countryCode = try container.decode(String.self, forKey: .countryCode)
        serviceWorkerUrl = try? container.decode(String.self, forKey: .serviceWorkerUrl)
        cdnUrl = try container.decode(String.self, forKey: .cdnUrl)
        sessionId = try? container.decode(String?.self, forKey: .sessionId)
    }

    init(widgets: [Widget], hasLogo: Bool, enabledGdpr: Bool, recaptchaSiteKey: String?, countryCode: String, serviceWorkerUrl: String?, cdnUrl: String, sessionId: String?) {
        self.widgets = widgets
        self.hasLogo = hasLogo
        self.enabledGdpr = enabledGdpr
        self.recaptchaSiteKey = recaptchaSiteKey
        self.countryCode = countryCode
        self.serviceWorkerUrl = serviceWorkerUrl
        self.cdnUrl = cdnUrl
        self.sessionId = sessionId
    }

    enum CodingKeys: String, CodingKey {
        case widgets
        case hasLogo = "has_logo"
        case enabledGdpr = "enabled_gdpr"
        case recaptchaSiteKey = "recaptcha_site_key"
        case countryCode = "country_code"
        case serviceWorkerUrl = "service_worker_url"
        case cdnUrl = "cdn_url"
        case expiry
        case sessionId = "session_id"
    }
}

struct WebViewConfig: Codable {
    let token: String
    let endpoint: String
    let captureJsUrl: String
    let data: WidgetsResponse
    let context: [String: String]?
}
