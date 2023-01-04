//
//  WebViewController.swift
//

import UIKit
import WebKit

open class WebViewController: BaseController, WKNavigationDelegate {
    
    public static var processNavigation: ((URL)->())?
    open var url: URL?
    open var request: URLRequest?
    open var html: String?
    open var webView = WKWebView()
    open var indicator = UIActivityIndicatorView(style: .medium)
    fileprivate var firstLoad: Bool = true
    
    fileprivate weak var failView: FailedView?
    
    public init(request: URLRequest) {
        self.request = request
        super.init()
    }
    
    public init(url: URL) {
        self.url = url
        super.init()
    }
    
    public init(html: String) {
        self.html = html
        super.init()
    }
    
    public override init() {
        super.init()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        webView.navigationDelegate = self
        view.attach(webView)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: indicator)
        
        if let request = request {
            webView.load(request)
        } else if let url = url {
            if FileManager.default.fileExists(atPath: url.path) {
                if let string = try? String.init(contentsOf: url) {
                    webView.loadHTMLString(string, baseURL: url.deletingLastPathComponent())
                }
            } else {
                webView.load(URLRequest(url: url))
            }
        } else if let html = html {
            webView.loadHTMLString(html, baseURL: Bundle.main.resourceURL)
        }
    }
    
    open func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        failView?.removeFromSuperview()
        indicator.startAnimating()
    }
    
    open func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        indicator.stopAnimating()
        if firstLoad {
            firstLoad = false
        }
    }
    
    open func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if firstLoad {
            failView = FailedView.loadFromNib(bundle: Bundle.module)
            failView?.present(in: view, text: error.localizedDescription, retry: { [weak self] in
                self?.webView.reload()
            })
        }
    }
    
    open func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, nil)
    }
    
    open func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated, let processNavigation = type(of: self).processNavigation, let url = navigationAction.request.url {
            processNavigation(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}

public extension WKWebView {
    
    private var sourceOfUserScript: String {
        return "(function(){\n" +
            "    var head = document.getElementsByTagName('head')[0];\n" +
            "    var nodes = head.getElementsByTagName('meta');\n" +
            "    var i, meta;\n" +
            "    for (i = 0; i < nodes.length; ++i) {\n" +
            "        meta = nodes.item(i);\n" +
            "        if (meta.getAttribute('name') == 'viewport')  break;\n" +
            "    }\n" +
            "    if (i == nodes.length) {\n" +
            "        meta = document.createElement('meta');\n" +
            "        meta.setAttribute('name', 'viewport');\n" +
            "        head.appendChild(meta);\n" +
            "    } else {\n" +
            "        meta.setAttribute('backup', meta.getAttribute('content'));\n" +
            "    }\n" +
            "    meta.setAttribute('content', 'width=device-width');\n" +
        "})();\n"
    }
    var scalesPageToFit: Bool {
        get {
            return objc_getAssociatedObject(self, "scalesPageToFit") != nil
        }
        set {
            if newValue {
                if objc_getAssociatedObject(self, "scalesPageToFit") != nil {
                    return
                }
                let time = WKUserScriptInjectionTime.atDocumentEnd
                let script = WKUserScript(source: sourceOfUserScript, injectionTime: time, forMainFrameOnly: true)
                configuration.userContentController.addUserScript(script)
                objc_setAssociatedObject(self, "scalesPageToFit", script, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                if url != nil {
                    evaluateJavaScript(sourceOfUserScript, completionHandler: nil)
                }
            } else if let script = objc_getAssociatedObject(self, "scalesPageToFit") as? WKUserScript {
                objc_setAssociatedObject(self, "scalesPageToFit", nil, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                configuration.userContentController.removeUserScript(script: script)
                if url != nil {
                    let source = "(function(){\n" +
                        "    var head = document.getElementsByTagName('head')[0];\n" +
                        "    var nodes = head.getElementsByTagName('meta');\n" +
                        "    for (var i = 0; i < nodes.length; ++i) {\n" +
                        "        var meta = nodes.item(i);\n" +
                        "        if (meta.getAttribute('name') == 'viewport' && meta.hasAttribute('backup')) {\n" +
                        "            meta.setAttribute('content', meta.getAttribute('backup'));\n" +
                        "            meta.removeAttribute('backup');\n" +
                        "        }\n" +
                        "    }\n" +
                    "})();"
                    evaluateJavaScript(source, completionHandler: nil)
                }
            }
        }
    }
}

extension WKUserContentController {
    public func removeUserScript(script: WKUserScript) {
        let scripts = userScripts
        removeAllUserScripts()
        scripts.forEach {
            if $0 != script { self.addUserScript($0) }
        }
    }
}
