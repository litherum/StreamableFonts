//
//  main.swift
//  RangeRequests
//
//  Created by Myles C. Maxfield on 4/8/19.
//  Copyright © 2019 Myles C. Maxfield. All rights reserved.
//

import Foundation

let session = URLSession(configuration: URLSessionConfiguration.ephemeral)
var request = URLRequest(url: URL(string: "https://fonts.gstatic.com/s/notosanssc/v4/k3kXo84MPvpLmixcA63oeALRLoKL.otf")!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 9999999999)
var start = Date()
var index = 0
var total = 0
var duration = TimeInterval(0)
var togetherDuration = TimeInterval(0)
func callback(data: Data?, response: URLResponse?, error: Error?) {
    let end = Date()
    duration += end.timeIntervalSince(start)
    let minimum = min(total, 1000)
    if index >= minimum {
        print("Took \(togetherDuration) to download \(total) bytes altogether, means each byte takes \(Double(togetherDuration) / Double(total)) seconds.")
        print("\(minimum) range requests took \(duration) seconds, means each range request takes \(Double(duration) / Double(minimum)) seconds.")
        print("Therefore, each range request costs \((Double(total) / Double(togetherDuration)) / (Double(minimum) / Double(duration))) bytes.")
        print("This equates to each range request costing \(((Double(total) / Double(togetherDuration)) / (Double(minimum) / Double(duration))) / Double(170)) characters.")
        CFRunLoopStop(CFRunLoopGetMain())
    } else {
        var request = URLRequest(url: URL(string: "https://fonts.gstatic.com/s/notosanssc/v4/k3kXo84MPvpLmixcA63oeALRLoKL.otf")!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 9999999999)
        request.addValue("bytes=\(index)-\(index + 1)", forHTTPHeaderField: "Range")
        index += 1
        let task = session.dataTask(with: request, completionHandler: callback)
        start = Date()
        task.resume()
    }
}

let task = session.dataTask(with: request) {(data, response, error) in
    let end = Date()
    total = data!.count
    togetherDuration = end.timeIntervalSince(start)
    var request = URLRequest(url: URL(string: "https://fonts.gstatic.com/s/notosanssc/v4/k3kXo84MPvpLmixcA63oeALRLoKL.otf")!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 9999999999)
    request.addValue("bytes=0-1", forHTTPHeaderField: "Range")
    index += 1
    let task = session.dataTask(with: request, completionHandler: callback)
    start = Date()
    task.resume()
}
start = Date()
task.resume()

CFRunLoopRun()
