import UIKit
import WebKit

class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private var webView: WKWebView!
    private let serverKey = "dwell_server_url"
    private var statusBarStyle: UIStatusBarStyle = .default

    override var preferredStatusBarStyle: UIStatusBarStyle { statusBarStyle }
    override var prefersStatusBarHidden: Bool { false }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.98, green: 0.976, blue: 0.96, alpha: 1)

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        loadDwell()
    }

    private func loadDwell() {
        if let saved = UserDefaults.standard.string(forKey: serverKey), let url = URL(string: saved) {
            webView.load(URLRequest(url: url))
        } else {
            showSetup()
        }
    }

    private func showSetup() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
        <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, system-ui, sans-serif;
            background: #faf9f5;
            color: #2b2a27;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            padding: 24px;
            padding-top: max(24px, env(safe-area-inset-top));
        }
        @media (prefers-color-scheme: dark) {
            body { background: #262624; color: #e8e5dc; }
            input { background: #363633; color: #e8e5dc; border-color: #4a4a46; }
            .hint { color: #8a867c; }
        }
        .logo { font-size: 48px; margin-bottom: 16px; }
        h1 { font-size: 20px; font-weight: 600; margin-bottom: 8px; }
        .hint { font-size: 13px; color: #8a867c; margin-bottom: 24px; text-align: center; line-height: 1.5; }
        input {
            width: 100%; max-width: 320px;
            padding: 12px 16px;
            border: 1px solid #e8e5dc;
            border-radius: 12px;
            font-size: 16px;
            background: #fff;
            outline: none;
            margin-bottom: 12px;
        }
        input:focus { border-color: #c96442; }
        button {
            width: 100%; max-width: 320px;
            padding: 12px;
            border: none;
            border-radius: 12px;
            background: #c96442;
            color: white;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
        }
        button:active { opacity: 0.8; }
        </style>
        </head>
        <body>
        <div class="logo">🦀</div>
        <h1>Lux Home</h1>
        <p class="hint">输入 Dwell 服务器地址<br>（电脑上 /api/tunnel 返回的地址）</p>
        <input id="url" type="url" placeholder="https://xxx.trycloudflare.com" autocapitalize="off" autocorrect="off">
        <button onclick="save()">连接</button>
        <script>
        function save() {
            var v = document.getElementById('url').value.trim().replace(/\\/+$/, '');
            if (!v) return;
            window.webkit.messageHandlers.setup.postMessage(v);
        }
        </script>
        </body>
        </html>
        """

        let userContentController = webView.configuration.userContentController
        userContentController.add(SetupHandler(vc: self), name: "setup")
        webView.loadHTMLString(html, baseURL: nil)
    }

    func connectTo(_ urlString: String) {
        UserDefaults.standard.set(urlString, forKey: serverKey)
        loadDwell()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url,
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.documentElement.dataset.theme || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light')") { [weak self] result, _ in
            let dark = (result as? String) == "dark"
            self?.statusBarStyle = dark ? .lightContent : .darkContent
            self?.setNeedsStatusBarAppearanceUpdate()
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }
}

class SetupHandler: NSObject, WKScriptMessageHandler {
    weak var vc: WebViewController?
    init(vc: WebViewController) { self.vc = vc }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let url = message.body as? String {
            vc?.connectTo(url)
        }
    }
}
