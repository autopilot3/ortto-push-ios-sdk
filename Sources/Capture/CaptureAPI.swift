//
//  File.swift
//  
//
//  Created by Mitch Flindell on 28/6/2023.
//

import Foundation
import OrttoPushSDKCore
import Alamofire

struct CaptureAPI {
    static func fetchWidgets(_ body: WidgetsGetRequest, completion: @escaping (WidgetsResponse) -> Void) {
        guard let url = URL(string: "\(Ortto.shared.apiEndpoint!)/-/widgets/get") else { return }
        
        print("WebViewController@fetchWidgets.url: \(url)")
        
        let headers: HTTPHeaders = [
            .accept("application/json"),
            .contentType("application/json")
        ]
        
        AF.request(url, method: .post, parameters: body, encoder: JSONParameterEncoder.default, headers: headers)
            .validate()
            .responseDecodable(of: WidgetsResponse.self) { response in
                debugPrint(response)
                
                if let widgetsResponse = try? response.result.get() {
                    let popups = widgetsResponse.widgets.filter { $0.type == WidgetType.popup }
                    
                    completion(WidgetsResponse(widgets: popups))
                } else {
                    completion(WidgetsResponse(widgets: []))
                }
            }
    }
}
