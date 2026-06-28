//
//  PaperShaderBackground.swift
//  Ortto iOS SDK Push Demo
//
//  Login-screen flourish: a transparent, non-interactive WKWebView running the
//  Paper Shaders WebGL mesh gradient (github.com/paper-design/shaders), loaded
//  from esm.sh at runtime. The web view stays invisible until the shader draws
//  its first frame, so the SwiftUI gradient behind it acts as both the loading
//  state and the offline fallback.
//

import SwiftUI
import WebKit

struct PaperShaderBackground: UIViewRepresentable {
    let provider: PushProvider

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "shaderReady")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isUserInteractionEnabled = false
        webView.alpha = 0
        context.coordinator.webView = webView

        webView.loadHTMLString(html(), baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "shaderReady")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        weak var webView: WKWebView?

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "shaderReady", let webView else { return }
            UIView.animate(withDuration: 0.8) { webView.alpha = 1 }
        }
    }

    private func html() -> String {
        // The shader takes RGBA vec4s in 0...1; reuse the provider's SwiftUI palette.
        let colors = provider.loginBaseColors.map { color -> [Double] in
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
            return [Double(r), Double(g), Double(b), Double(a)]
        }
        let colorsJSON = (try? JSONEncoder().encode(colors)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        return """
        <!doctype html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, viewport-fit=cover">
        <style>html, body { margin: 0; height: 100%; background: transparent; overflow: hidden } #mesh { position: fixed; inset: 0 }</style>
        </head>
        <body>
        <div id="mesh"></div>
        <script type="module">
        import { ShaderMount, meshGradientFragmentShader } from "https://esm.sh/@paper-design/shaders@0.0.76";

        new ShaderMount(
            document.getElementById("mesh"),
            meshGradientFragmentShader,
            {
                u_colors: \(colorsJSON),
                u_colorsCount: \(colors.count),
                u_distortion: 0.8,
                u_swirl: 0.4,
                u_grainMixer: 0,
                u_grainOverlay: 0,
                u_fit: 2,
                u_scale: 1,
                u_rotation: 0,
                u_offsetX: 0,
                u_offsetY: 0,
                u_originX: 0.5,
                u_originY: 0.5,
                u_worldWidth: 0,
                u_worldHeight: 0
            },
            undefined,
            0.5
        );
        requestAnimationFrame(() => window.webkit.messageHandlers.shaderReady.postMessage(true));
        </script>
        </body>
        </html>
        """
    }
}
