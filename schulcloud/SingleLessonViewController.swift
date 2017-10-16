//
//  SingleLessonViewController.swift
//  schulcloud
//
//  Created by Carl Julius Gödecken on 17.06.17.
//  Copyright © 2017 Hasso-Plattner-Institut. All rights reserved.
//

import UIKit
import WebKit

class SingleLessonViewController: UIViewController, WKUIDelegate {
    
    var lesson: Lesson!
    
    var webView: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let userContentController = WKUserContentController()
        let cookieScriptSource = "document.cookie = 'jwt=\(Globals.account!.accessToken!)'"
        let cookieScript = WKUserScript(source: cookieScriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        userContentController.addUserScript(cookieScript)
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.userContentController = userContentController
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.uiDelegate = self

        self.view.addSubview(webView)

        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        let guide = self.view.readableContentGuide
        guide.leadingAnchor.constraint(equalTo: webView.leadingAnchor).isActive = true
        guide.trailingAnchor.constraint(equalTo: webView.trailingAnchor).isActive = true

        self.title = lesson.name

        if let contents = lesson.contents {
            self.loadContents(contents)
        }
    }

    func loadContents(_ contents: NSOrderedSet) {
        let rendered = (contents.array as! [Content]).map(htmlForElement)
        let concatenated = "<html><head>\(Constants.textStyleHtml)<meta name=\"viewport\" content=\"initial-scale=1.0\"></head>" + rendered.joined(separator: "<hr>") + "</body></html>"
        webView.loadHTMLString(concatenated, baseURL: Constants.Servers.web.url)
    }
    
    func htmlForElement(_ content: Content) -> String {
        switch(content.type) {
        case .text:
            var rendered = ""
            if let title = content.title, !title.isEmpty {
                rendered += "<h1>\(title)</h1>"
            }
            rendered += content.text ?? ""
            return rendered
        case .other:
            return "<span class=\"not-supported\">Dieser Typ wird leider noch nicht unterstützt.</span>"
        }
    }
    
}
