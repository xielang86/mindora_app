import UIKit
import WebKit

/// 商店 Tab：直接载入网页商城（Constants.Network.shopURL）。
///
/// 页面自带 header / 导航，所以这里不再叠原生头部，webView 一路铺到屏幕顶端 ——
/// 让商城首页那张米色底图顶到状态栏后面，而不是在状态栏位置留一条白条。
/// 网页自己的 fixed header 由 [safeAreaScript] 注入的 CSS 往下推一个安全区高度。
/// （底部安全区已由 MainTabBarController 的 additionalSafeAreaInsets 抬到自定义 tab bar 之上）。
final class StoreViewController: UIViewController {

    // MARK: - UI

    private lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.addUserScript(
            WKUserScript(source: Self.safeAreaScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        config.userContentController.add(WeakScriptMessageProxy(self), name: Self.safeAreaHandler)
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.navigationDelegate = self
        wv.uiDelegate = self
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.backgroundColor = Self.pageBackground
        wv.isOpaque = false
        return wv
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let iv = UIActivityIndicatorView(style: .medium)
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.hidesWhenStopped = true
        return iv
    }()

    private let refreshControl = UIRefreshControl()

    /// 加载失败时的兜底视图（无网 / 服务不可用）
    private lazy var errorView: UIView = {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .white
        container.isHidden = true

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = L("auth.error.network")
        label.textColor = UIColor(white: 0.4, alpha: 1.0)
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.textAlignment = .center

        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(L("common.retry"), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 128/255, green: 84/255, blue: 254/255, alpha: 1.0)
        button.layer.cornerRadius = 20
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 28, bottom: 10, right: 28)
        button.addTarget(self, action: #selector(reloadTapped), for: .touchUpInside)

        container.addSubview(label)
        container.addSubview(button)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -40),

            button.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20),
            button.centerXAnchor.constraint(equalTo: container.centerXAnchor)
        ])
        return container
    }()

    /// 首屏是否已经成功载入过：没有的话失败才展示兜底页，避免二次刷新失败时白屏盖住已有内容
    private var hasLoadedOnce = false

    /// 网页 body 的底色（common.css 里的 `--bg`）。webView 铺到屏幕顶端后，
    /// 状态栏后面露出的就是它，原来那条白条来自这里默认的白色。
    private static let pageBackground = UIColor(red: 0xF4/255.0, green: 0xED/255.0, blue: 0xE3/255.0, alpha: 1)

    private static let safeAreaHandler = "storeSafeArea"

    /// 把状态栏高度让给网页自己的 fixed header：
    /// `--head` 是商城全站用来给内容留出顶部空间的变量（`.head-inner` 的高度、各页面的
    /// `padding-top` 都读它），加上安全区高度后整页内容自动下移，`.head-inner` 再补一个
    /// 同高的 padding-top，logo / 搜索 / 购物车就仍然落在状态栏下面。
    /// 商城改版后如果找不到 `.head-inner`，回传 false，由原生退回「webView 从安全区开始」。
    private static let safeAreaScript = """
    (function () {
      var meta = document.querySelector('meta[name=viewport]');
      if (meta && meta.content.indexOf('viewport-fit') < 0) {
        meta.content += ',viewport-fit=cover';
      }
      var patchable = !!document.querySelector('.head-inner');
      if (patchable && !document.getElementById('mindora-safe-area')) {
        var style = document.createElement('style');
        style.id = 'mindora-safe-area';
        style.textContent =
          '@media screen and (max-width:768px){' +
          'body{--head:calc(69px + env(safe-area-inset-top,0px));}' +
          '.head-inner{box-sizing:border-box;padding-top:env(safe-area-inset-top,0px);}' +
          '}';
        document.head.appendChild(style);
      }
      window.webkit.messageHandlers.storeSafeArea.postMessage(patchable);
    })();
    """

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Self.pageBackground
        setupUI()
        loadShop()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    // MARK: - Setup

    private func setupUI() {
        view.addSubview(webView)
        view.addSubview(errorView)
        view.addSubview(loadingIndicator)

        refreshControl.addTarget(self, action: #selector(reloadTapped), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            errorView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            errorView.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
            errorView.bottomAnchor.constraint(equalTo: webView.bottomAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: webView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: webView.centerYAnchor)
        ])
    }

    // MARK: - Load

    private func loadShop() {
        guard let url = URL(string: Constants.Network.shopURL) else { return }
        errorView.isHidden = true
        loadingIndicator.startAnimating()
        var request = URLRequest(url: url)
        request.timeoutInterval = Constants.Network.timeoutInterval
        webView.load(request)
    }

    @objc private func reloadTapped() {
        // 首屏都没成功过时 webView 没有 URL，reload() 是空操作，得重新发起
        if hasLoadedOnce, webView.url != nil {
            errorView.isHidden = true
            loadingIndicator.startAnimating()
            webView.reload()
        } else {
            loadShop()
        }
    }

    private func finishLoading(success: Bool) {
        loadingIndicator.stopAnimating()
        refreshControl.endRefreshing()
        if success {
            hasLoadedOnce = true
            errorView.isHidden = true
        } else if !hasLoadedOnce {
            errorView.isHidden = false
        }
    }
}

// MARK: - 顶部安全区

extension StoreViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == Self.safeAreaHandler else { return }
        let patched = (message.body as? Bool) ?? false
        // 网页没被改造成功（改版换了类名）就别让它顶到状态栏后面，退回留白
        let inset = patched ? 0 : view.safeAreaInsets.top
        guard webView.scrollView.contentInset.top != inset else { return }
        webView.scrollView.contentInset.top = inset
        webView.scrollView.verticalScrollIndicatorInsets.top = inset
        if webView.scrollView.contentOffset.y <= 0 {
            webView.scrollView.contentOffset.y = -inset
        }
    }
}

// MARK: - WKNavigationDelegate

extension StoreViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        // 非 http(s)（tel: / mailto: / 支付跳转等）交给系统，webView 自己处理不了
        if let scheme = url.scheme?.lowercased(), scheme != "http", scheme != "https" {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finishLoading(success: true)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Log.error("Store", "网页加载失败: \(error.localizedDescription)")
        finishLoading(success: false)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        // 用户主动打断（点击新链接 / 快速刷新）不算失败，别弹兜底页
        if (error as NSError).code == NSURLErrorCancelled {
            loadingIndicator.stopAnimating()
            refreshControl.endRefreshing()
            return
        }
        Log.error("Store", "网页加载失败: \(error.localizedDescription)")
        finishLoading(success: false)
    }
}

// MARK: - WKUIDelegate

extension StoreViewController: WKUIDelegate {
    /// target="_blank" 默认不会新开页面，转成当前 webView 载入，否则点了没反应
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("common.ok"), style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("common.cancel"), style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: L("common.ok"), style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }
}

/// `WKUserContentController` 会强引用 handler，直接传 VC 会形成 VC → webView → controller → VC 的环。
private final class WeakScriptMessageProxy: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) { self.target = target }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
