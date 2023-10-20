//
//  File.swift
//
//
//  Created by Mitchell Flindell on 18/7/2023.
//

import WebKit

class FullScreenWebView: WKWebView {
    override var safeAreaInsets: UIEdgeInsets {
        .zero
    }
}
