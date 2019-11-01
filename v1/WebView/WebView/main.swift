//
//  main.swift
//  WebView
//
//  Created by Myles C. Maxfield on 4/3/19.
//  Copyright © 2019 Myles C. Maxfield. All rights reserved.
//

import Foundation
import WebKit

var theURLs = urls()
var index = 0
var webView: WKWebView!
var results = [[String : String]]()

func performNextNavigation() {
    print("Fetching \(index)...")
    let url = theURLs[index]
    webView.load(URLRequest(url: url))
}

class NavigationDelegate: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.documentElement.innerText") {(result, error) in
            defer {
                let newIndex = index + 1
                if newIndex < theURLs.count {
                    index = newIndex
                    performNextNavigation()
                } else {
                    do {
                        let data = try PropertyListSerialization.data(fromPropertyList: results, format: .xml, options: 0)
                        try data.write(to: URL(fileURLWithPath: "/Users/litherum/tmp/ChineseWebsites.plist"))
                    } catch {
                        print("Could not write property list")
                    }
                    
                    CFRunLoopStop(CFRunLoopGetCurrent())
                }
            }
            guard error == nil else {
                print("Evaluating Javascript returned an error")
                return
            }
            guard let stringResult = result as? String else {
                print("Javascript didn't return a string")
                return
            }
            results.append(["URL" : theURLs[index].absoluteString, "Result" : stringResult])
        }
    }
}

let webConfiguration = WKWebViewConfiguration()
webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600), configuration: webConfiguration)
let navigationDelegate = NavigationDelegate()
webView.navigationDelegate = navigationDelegate

performNextNavigation()

CFRunLoopRun()
