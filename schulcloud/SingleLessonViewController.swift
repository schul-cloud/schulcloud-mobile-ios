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
    
    override func loadView() {
        let webConfiguration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.uiDelegate = self
        view = webView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = lesson.name
        
        if let contents = lesson.contents {
            self.loadContents(contents)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        navigationController?.hidesBarsOnSwipe = true
        navigationController?.hidesBarsOnTap = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.hidesBarsOnSwipe = false
        navigationController?.hidesBarsOnTap = false
    }
    
    func loadContents(_ contents: NSOrderedSet) {
        let rendered = (contents.array as! [Content]).map(htmlForElement)
        let concatenated = "<html><head>\(Constants.textStyleHtml)<meta name=\"viewport\" content=\"initial-scale=1.0\"></head>" + rendered.joined(separator: "<hr>") + "</body></html>"
        webView.loadHTMLString(concatenated, baseURL: nil)
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
            return "Dieser Typ wird leider noch nicht unterstützt"
        }
    }
    
}