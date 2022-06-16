//
//  CodeMirrorWebView.swift
//  NSProxy
//
//  Created by Nghia Tran on 4/26/20.
//  Copyright © 2020 com.nsproxy.proxy. All rights reserved.
//

import Foundation
import WebKit

#if os(OSX)
    import AppKit
    public typealias NativeView = NSView
#elseif os(iOS)
    import UIKit
    public typealias NativeView = UIView
#endif

private extension Data {
    func hexEncodedString() -> String {
        map { String(format: "%02hhx", $0) }.joined()
    }
}

// MARK: CodeMirrorWebViewDelegate

public protocol CodeMirrorWebViewDelegate: AnyObject {

    func codeMirrorViewDidLoadSuccess(_ sender: CodeMirrorWebView)
    func codeMirrorViewDidLoadError(_ sender: CodeMirrorWebView, error: Error)
    func codeMirrorViewDidChangeContent(_ sender: CodeMirrorWebView, content: String)
}

// MARK: JavascriptFunction

// JS Func
public typealias JavascriptCallback = (Result<Any?, Error>) -> Void
public struct JavascriptFunction {

    let functionString: String
    let argments: [String: Any]? // Only use for macOS 10.11 with modern APIs
    let callback: JavascriptCallback?

    init(functionString: String, argments: [String: Any]?, callback: JavascriptCallback?) {
        self.functionString = functionString
        self.callback = callback
        self.argments = argments
    }
}

// MARK: CodeMirrorWebView

public final class CodeMirrorWebView: NativeView {

    private struct Constants {
        static let codeMirrorDidReady = "codeMirrorDidReady"
        static let codeMirrorTextContentDidChange = "codeMirrorTextContentDidChange"
    }

    public enum BeautifyMode {
        case html
        case js
        case css
        case none

        var toJSCode: String {
            // Use string boolean by intention
            var isHexValue = "true"
            if #available(OSX 11.2, *) {
                // In Big Sur, we directly pass the value to the func call
                isHexValue = "false"
            } else {
                // Catalina and pior, we need to convert to Hex
                // To prevent Invalid escape string in the body
                isHexValue = "true"
            }
            switch self {
            case .css:
                return "BeautifyCSS(content, \(isHexValue));"
            case .html:
                return "BeautifyHTML(content, \(isHexValue));"
            case .js:
                return "BeautifyJS(content, \(isHexValue));"
            case .none:
                return "SetContent(content, \(isHexValue));"
            }
        }
    }

    public enum AutoCompleteMode {
        case httpMessage
        case scripting

        func toJSCmd(isEnabled: Bool) -> String {
            switch self {
            case .httpMessage:
                return "SetEnableHTTPMessageAutoComplete(\(isEnabled));"
            case .scripting:
                return "SetEnableScriptingAutoComplete(\(isEnabled));"
            }
        }
    }

    // MARK: Variables

    weak var delegate: CodeMirrorWebViewDelegate?
    var onLoaded: (() -> Void)?
    var onProcessing: ((Bool) -> Void)?

    private lazy var webview: WKWebView = {
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        var userController = WKUserContentController()
        userController.add(self, name: Constants.codeMirrorDidReady) // Callback from CodeMirror JS
        userController.add(self, name: Constants.codeMirrorTextContentDidChange)
        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        configuration.userContentController = userController
        let webView = WKWebView(frame: bounds, configuration: configuration)
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }()

    private var pageLoaded = false
    private var pendingFunctions = [JavascriptFunction]()
    private let queue = DispatchQueue(label: "com.proxyman.CodeMirrorWebView", qos: .default)

    // MARK: Init

    override init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        initWebView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initWebView()
    }

    // MARK: Properties

    public func setTabInsertsSpaces(_ value: Bool) {
        callJavascript(javascriptString: "SetTabInsertSpaces(\(value));")
    }

    public func setContent(_ value: String, beautifyMode: BeautifyMode = .none) {
        onProcessing?(true)

        // Get setContent JS
        let setContentCmd = beautifyMode.toJSCode

        // Execute JS
        if #available(OSX 11.2, *) {
            //
            // Use modern APIs
            // pass the value as a argment
            // It means we don't need to convert to Hex value anymore
            //
            callJavascript(javascriptString: setContentCmd, argments: ["content": value]) {[weak self] (_) in
                guard let strongSelf = self else { return }
                strongSelf.onProcessing?(false)
            }
        } else {
            //
            // It's tricky to pass FULL JSON or HTML text with \n or "", ... into JS Bridge
            // And use String.raw`content_goes_here`
            // Update 1: String.raw`` doesn't work anymore if the content has `${}` string
            //
            // Reasonable solution is that we convert to hex, then converting back to string in JS
            //

            queue.async {
                if let hexString = value.data(using: .utf8)?.hexEncodedString() {
                    let script = """
                    var content = "\(hexString)"; \(setContentCmd);
                    """
                    DispatchQueue.main.async {[weak self] in
                        guard let strongSelf = self else { return }
                        strongSelf.callJavascript(javascriptString: script) { _ in
                            strongSelf.onProcessing?(false)
                        }
                    }

                } else {
                    let script = """
                    var content = "Couldn't convert to UTF8 Text"; SetContent(content);
                    """
                    DispatchQueue.main.async {[weak self] in
                        guard let strongSelf = self else { return }
                        strongSelf.callJavascript(javascriptString: script) { _ in
                            strongSelf.onProcessing?(false)
                        }
                    }
                }
            }
        }
    }

    public func clearContent() {
        let script = """
        SetContent("");
        """
        callJavascript(javascriptString: script)
    }

    public func getContent(_ block: JavascriptCallback?) {
        callJavascript(javascriptString: "GetContent();", callback: block)
    }

    public func setMimeType(_ value: String) {
        var newType = value
        if value.hasPrefix("application/json") {
            newType = "application/ld+json"
        }
        callJavascript(javascriptString: "SetMimeType(\"\(newType)\");")
    }

    public func setDarkTheme(_ isDark: Bool) {
        let themeName = isDark ? "material" : "base16-light"
        callJavascript(javascriptString: "SetTheme(\"\(themeName)\");")
    }

    public func setLineWrapping(_ value: Bool) {
        callJavascript(javascriptString: "SetLineWrapping(\(value));")
    }

    public func setFontSize(_ value: Int) {
        callJavascript(javascriptString: "SetFontSize(\(value));")
    }

    public func setDefaultTheme() {
        setMimeType("application/json")
    }

    public func setReadonly(_ value: Bool) {
        callJavascript(javascriptString: "SetReadOnly(\(value));")
    }

    public func getTextSelection(_ block: JavascriptCallback?) {
        callJavascript(javascriptString: "GetTextSelection();", callback: block)
    }

    public func toggleFilterBar() {
        callJavascript(javascriptString: "ToggleFilterBar();")
    }

    public func setIsEnabledForAutoComplete(autoComplete: AutoCompleteMode, isEnabled: Bool) {
        callJavascript(javascriptString: autoComplete.toJSCmd(isEnabled: isEnabled))
    }

    // MARK: Private

    private func callJavascript(javascriptString: String, argments: [String: Any]? = nil, callback: JavascriptCallback? = nil) {
        if pageLoaded {
            callJavascriptFunction(function: JavascriptFunction(functionString: javascriptString, argments: argments, callback: callback))
        }
        else {
            addFunction(function: JavascriptFunction(functionString: javascriptString, argments: argments, callback: callback))
        }
    }
}

// MARK: Private

extension CodeMirrorWebView {

    private func initWebView() {
        webview.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webview)
        webview.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        webview.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        webview.topAnchor.constraint(equalTo: topAnchor).isActive = true
        webview.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

        // Load CodeMirror bundle
        
        guard let bundlePath = Bundle.module.path(forResource: "CodeMirrorView", ofType: "bundle"),
            let bundle = Bundle(path: bundlePath),
            let indexPath = bundle.path(forResource: "index", ofType: "html") else {
                fatalError("CodeMirrorBundle is missing")
        }
        let data = try! Data(contentsOf: URL(fileURLWithPath: indexPath))
        webview.load(data, mimeType: "text/html", characterEncodingName: "utf-8", baseURL: bundle.resourceURL!)
    }

    private func addFunction(function:JavascriptFunction) {
        pendingFunctions.append(function)
    }

    private func callJavascriptFunction(function: JavascriptFunction) {

        // If the argment is available, it means we would use a modern API
        if let argments = function.argments {

            // Only available in 11.2
            // User 11.0.1 has a lot of crashes
            // https://bugs.webkit.org/show_bug.cgi?id=208593
            if #available(OSX 11.2, iOS 14.0, *) {
                webview.callAsyncJavaScript(function.functionString, arguments: argments, in: nil, in: .page) {(result) in
                    switch result {
                    case .failure(let error):
                        function.callback?(Result<Any?, Error>.failure(error))
                    case .success(let data):
                        function.callback?(Result<Any?, Error>.success(data))
                    }
                }
                return
            }
        }

        // Legacy for back compatible
        webview.evaluateJavaScript(function.functionString) { (response, error) in
            if let error = error {
                function.callback?(Result<Any?, Error>.failure(error))
            } else {
                function.callback?(Result<Any?, Error>.success(response))
            }
        }
    }

    private func callPendingFunctions() {
        for function in pendingFunctions {
            callJavascriptFunction(function: function)
        }
        pendingFunctions.removeAll()
    }
}

// MARK: WKNavigationDelegate

extension CodeMirrorWebView: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        delegate?.codeMirrorViewDidLoadSuccess(self)
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        delegate?.codeMirrorViewDidLoadError(self, error: error)
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        delegate?.codeMirrorViewDidLoadError(self, error: error)
    }
}

// MARK: WKScriptMessageHandler

extension CodeMirrorWebView: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {

        // is Ready
        if message.name == Constants.codeMirrorDidReady {
            pageLoaded = true
            callPendingFunctions()
            return
        }

        // Content change
        if message.name == Constants.codeMirrorTextContentDidChange {
            let content = (message.body as? String) ?? ""
            delegate?.codeMirrorViewDidChangeContent(self, content: content)
        }
    }
}
