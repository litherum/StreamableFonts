//
//  MeasureRoundTripTime.swift
//  Optimizer
//
//  Created by Myles C. Maxfield on 4/9/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

import Foundation

public struct Sample {
    public let payloadSize: Int
    public let latency: TimeInterval
}

public protocol RoundTripTimeMeasurerDelegate : class {
    func prepared(length: Int?)
    func producedSample(sample: Sample?)
}

public class RoundTripTimeMeasurer {
    private let url: URL
    private let trials: Int
    private var length = 0
    private let session: URLSession
    private weak var delegate: RoundTripTimeMeasurerDelegate?

    public init?(url: URL, trials: Int, delegate: RoundTripTimeMeasurerDelegate) {
        self.url = url
        self.trials = trials
        self.delegate = delegate

        if trials < 2 {
            self.delegate?.prepared(length: nil)
            return nil
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
    }

    fileprivate func pump(trial: Int) {
        guard trial < trials else {
            return
        }
        var request = URLRequest(url: url)
        let endByteOffset = Int(Float(trial) / Float(trials) * Float(length))
        let startByteOffset = Int(sqrt(Float(endByteOffset)))
        request.addValue("bytes=\(startByteOffset)-\(endByteOffset)", forHTTPHeaderField: "Range")
        var startTime: Date!
        let task = session.dataTask(with: request) {(data, response, error) in
            let endTime = Date()
            guard data != nil && response != nil && error == nil else {
                self.delegate?.producedSample(sample: nil)
                self.pump(trial: trial + 1)
                return
            }
            self.delegate?.producedSample(sample: Sample(payloadSize: data!.count, latency: startTime.distance(to: endTime)))
            self.pump(trial: trial + 1)
        }
        startTime = Date()
        task.resume()
    }

    // FIXME: Consider moving these callbacks into a delegate interface.
    public func measure() {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        let task = session.dataTask(with: request) {(data, response, error) in
            guard response != nil && error == nil else {
                self.delegate?.prepared(length: nil)
                return
            }
            guard let httpResponse = response! as? HTTPURLResponse else {
                self.delegate?.prepared(length: nil)
                return
            }
            guard let acceptRangesString = httpResponse.value(forHTTPHeaderField: "Accept-Ranges") else {
                self.delegate?.prepared(length: nil)
                return
            }
            guard acceptRangesString.split(separator: ",").map({$0.trimmingCharacters(in: .whitespaces)}).firstIndex(of: "bytes") != nil else {
                self.delegate?.prepared(length: nil)
                return
            }
            guard let lengthString = httpResponse.value(forHTTPHeaderField: "Content-Length") else {
                self.delegate?.prepared(length: nil)
                return
            }
            guard let length = Int(lengthString) else {
                self.delegate?.prepared(length: nil)
                return
            }
            self.length = length
            self.delegate?.prepared(length: length)
            self.pump(trial: 0)
        }
        task.resume()
    }

    public class func calculateRoundTripOverheadInBytes(samples: [Sample]) -> Double? {
        guard !samples.isEmpty else {
            return nil
        }

        let xAverage = Double(samples.reduce(0) {$0 + $1.payloadSize}) / Double(samples.count)
        let yAverage = Double(samples.reduce(0) {$0 + $1.latency}) / Double(samples.count)
        var numerator = Double(0)
        var denominator = Double(0)
        for sample in samples {
            let deltaX = Double(sample.payloadSize) - xAverage
            let deltaY = Double(sample.latency) - yAverage
            numerator += deltaX * deltaY
            denominator += deltaX * deltaX
        }
        // y = alpha + beta * x
        let beta = numerator / denominator // TimeInterval / bytes
        let alpha = yAverage - beta * xAverage // TimeInterval

        let result = alpha / beta
        guard result >= 0 else {
            return nil
        }
        return result
    }
}
