//
//  main.swift
//  FontOptimizerCLI
//
//  Created by Myles C. Maxfield on 4/9/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

import Foundation
import CoreText
import Metal
import Optimizer

fileprivate func printUsage() {
    print("Usage: \(CommandLine.arguments[0]) [--iterations <count>] [--fontIndex <index>] [--sampleSize <size>] [--roundTripURL <url>] [--roundTripTrials <trials>] [--roundTripStartupCostInBytes <byteCount>] [--seedCount <count>] [--silent] corpusfile inputfile outputfile")
}

class FontOptimizer: Optimizer.RoundTripTimeMeasurerDelegate, Optimizer.FontOptimizerDelegate {
    public var corpusFile: String!
    public var inputFile: String!
    public var outputFile: String!
    public var fontIndex = 0
    public var iterations = 10
    public var sampleSize: Int?
    public var roundTripURL: URL?
    public var roundTripTrials = 10
    public var roundTripStartupCostInBytes = 0
    public var seedCount = 5
    public var silent = false

    // FIXME: Better error logging
    public var callback: ((Bool) -> Void)!

    private var font: CTFont!
    private var glyphSizes: Optimizer.GlyphSizes!
    private var urlContents = [String]()
    private var requiredGlyphs = [Set<CGGlyph>]()
    private var roundTripTimeMeasurer: Optimizer.RoundTripTimeMeasurer!
    private var roundTripSamples = [Optimizer.Sample]()
    private var roundTripSampleCount = 0
    private var roundTripTimeMeasurerDelegate: Optimizer.RoundTripTimeMeasurerDelegate!
    private var device: MTLDevice!
    private var prunedGlyphs: Optimizer.PrunedGlyphs!
    private var seeds = [[Int]]()
    private var fontOptimizer: Optimizer.FontOptimizer!

    public var isConfigured: Bool {
        get {
            return corpusFile != nil && inputFile != nil && outputFile != nil && callback != nil
        }
    }

    private func log(_ message: String) {
        if !silent {
            print(message)
        }
    }

    public func optimize() {
        optimizeStep1()
    }

    private func optimizeStep1() {
        log("Investigating input font file...")
        guard let fontDescriptors = CTFontManagerCreateFontDescriptorsFromURL(URL(fileURLWithPath: inputFile) as NSURL) as? [CTFontDescriptor] else {
            callback(false)
            return
        }
        if fontIndex >= fontDescriptors.count {
            callback(false)
            return
        }
        font = CTFontCreateWithFontDescriptor(fontDescriptors[fontIndex], 0, nil)
        guard let glyphSizes = Optimizer.GlyphSizesComputer.computeGlyphSizes(font: font) else {
            callback(false)
            return
        }
        self.glyphSizes = glyphSizes

        do {
            log("Investigating corpus...")
            let data = try Data(contentsOf: URL(fileURLWithPath: corpusFile))
            guard let jsonData = try JSONSerialization.jsonObject(with: data) as? [Any] else {
                callback(false)
                return
            }
            for i in jsonData {
                guard let item = i as? NSDictionary, let c = item.value(forKey: "Contents"), let contents = c as? String else {
                    callback(false)
                    return
                }
                urlContents.append(contents)
            }
            if sampleSize != nil {
                log("Sampling corpus...")
                guard let randomSample = Optimizer.randomSample(urlContents: urlContents, sampleCount: sampleSize!) else {
                    callback(false)
                    return
                }
                urlContents = randomSample
            }

            log("Transforming corpus from character-space to glyph-space...")
            requiredGlyphs = Array(repeating: Set<CGGlyph>(), count: urlContents.count)
            var count = 0
            let _ = computeRequiredGlyphs(font: font, urlContents: urlContents) {(index: Int, set: Set<CGGlyph>?) in
                OperationQueue.main.addOperation {
                    count += 1
                    if let glyphs = set {
                        self.requiredGlyphs[index] = glyphs
                    }
                    self.log("Transformed url contents #\(count) / \(self.urlContents.count)")
                    if count == self.urlContents.count {
                        self.optimizeStep2()
                    }
                }
            }
            
        } catch {
            callback(false)
            return
        }
    }

    private func optimizeStep2() {
        guard let roundTripURL = self.roundTripURL else {
            optimizeStep3()
            return
        }

        log("Measuing round-trip time...")
        guard let roundTripTimeMeasurer = Optimizer.RoundTripTimeMeasurer(url: roundTripURL, trials: roundTripTrials, delegate: self) else {
            callback(false)
            return
        }
        self.roundTripTimeMeasurer = roundTripTimeMeasurer
        roundTripTimeMeasurer.measure()
    }
    
    
    func prepared(length: Int?) {
        guard length != nil else {
            callback(false)
            return
        }
        print("Round trip timer prepared.")
    }
    
    func producedSample(sample: Sample?) {
        roundTripSampleCount += 1
        if let producedSample = sample {
            roundTripSamples.append(producedSample)
        }
        print("Received response #\(roundTripSampleCount) / \(roundTripTrials)")
        if roundTripSampleCount == roundTripTrials {
            OperationQueue.main.addOperation {
                guard let roundTripOverhead = RoundTripTimeMeasurer.calculateRoundTripOverheadInBytes(samples: self.roundTripSamples) else {
                    self.callback(false)
                    return
                }
                self.roundTripStartupCostInBytes = Int(roundTripOverhead)
                self.optimizeStep3()
            }
        }
    }

    private func optimizeStep3() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            callback(false)
            return
        }
        self.device = device

        log("Pruning glyphs...")
        prunedGlyphs = Optimizer.pruneGlyphs(glyphSizes: glyphSizes, requiredGlyphs: requiredGlyphs)
        seeds = [[Int]]()

        guard seedCount > 0 else {
            callback(false)
            return
        }

        if seeds.count < seedCount {
            log("Calculating seed #\(seeds.count + 1)...")
            let order = Optimizer.frequencyOrder(glyphCount: prunedGlyphs.glyphSizes.glyphSizes.count, requiredGlyphs: prunedGlyphs.requiredGlyphs)
            seeds.append(order)
        }

        if seeds.count < seedCount {
            log("Computing bigram scores...")
            Optimizer.computeBigramScores(glyphCount: prunedGlyphs.glyphSizes.glyphSizes.count, requiredGlyphs: prunedGlyphs.requiredGlyphs, device: device) {(bigramScores: [[Float]]?) in
                OperationQueue.main.addOperation {
                    guard let scores = bigramScores else {
                        self.callback(false)
                        return
                    }

                    var count = 0
                    let progressCallback = {
                        self.log("Placed glyph \(count) of \(self.prunedGlyphs.glyphSizes.glyphSizes.count)")
                        count += 1
                    }

                    self.log("Calculating seed #\(self.seeds.count + 1)...")
                    if let order = Optimizer.lastBest(glyphCount: self.prunedGlyphs.glyphSizes.glyphSizes.count, bigramScores: scores, progressCallback: progressCallback) {
                        self.seeds.append(order)
                    }

                    if self.seeds.count < self.seedCount {
                        self.log("Calculating seed #\(self.seeds.count + 1)...")
                        count = 0
                        if let order = Optimizer.placedBest(glyphCount: self.prunedGlyphs.glyphSizes.glyphSizes.count, bigramScores: scores, progressCallback: progressCallback) {
                            self.seeds.append(order)
                        }
                    }

                    if self.seedCount - self.seeds.count > 0 {
                        self.log("Generating \(self.seedCount - self.seeds.count) random seeds...")
                        let randomSeeds = Optimizer.generateRandomSeeds(glyphCount: self.prunedGlyphs.glyphSizes.glyphSizes.count, seedCount: self.seedCount - self.seeds.count)
                        self.seeds.append(contentsOf: randomSeeds)
                    }

                    self.optimizeStep4()
                }
            }
        } else {
            optimizeStep4()
        }
    }

    private func optimizeStep4() {
        var totalGlyphSize = 0
        for i in 0 ..< glyphSizes.glyphSizes.count {
            totalGlyphSize += glyphSizes.glyphSizes[i]
        }
        let unconditionalDownloadSize = glyphSizes.fontSize - totalGlyphSize

        self.log("Initiating optimization...")
        guard let fontOptimizer = Optimizer.FontOptimizer(glyphSizes: prunedGlyphs.glyphSizes.glyphSizes, requiredGlyphs: prunedGlyphs.requiredGlyphs, seeds: seeds, threshold: roundTripStartupCostInBytes, unconditionalDownloadSize: unconditionalDownloadSize, fontSize: glyphSizes.fontSize, device: device, iterationCount: iterations, delegate: self) else {
            callback(false)
            return
        }
        self.fontOptimizer = fontOptimizer
        fontOptimizer.prepare()
    }


    func prepared(success: Bool) {
        OperationQueue.main.addOperation {
            self.log("Optimizer prepared.")
            guard success else {
                self.callback(false)
                return
            }
            self.fontOptimizer.optimize()
        }
    }
    
    func report(fitness: Float) {
        self.log("Intermediate fitness: \(fitness * 100)%.")
    }
    
    func stopped(results optimizerResults: Optimizer.OptimizerResults?) {
        OperationQueue.main.addOperation {
            guard let results = optimizerResults else {
                self.callback(false)
                return
            }

            self.log("Gathering final results...")
            var order = [CGGlyph]()
            var usedGlyphs = Set<CGGlyph>()
            for mappedGlyph in results.glyphOrder {
                let unmappedGlyph = self.prunedGlyphs.reverseGlyphMapping[Int(mappedGlyph)]
                order.append(unmappedGlyph)
                usedGlyphs.insert(unmappedGlyph)
            }
            for i in 0 ..< self.glyphSizes.glyphSizes.count {
                if !usedGlyphs.contains(CGGlyph(i)) {
                    order.append(CGGlyph(i))
                    usedGlyphs.insert(CGGlyph(i))
                }
            }

            self.log("Outputting reordered font file...")
            guard Optimizer.reorderFont(inputFilename: self.inputFile, fontNumber: self.fontIndex, glyphOrder: order, outputFilename: self.outputFile) else {
                self.callback(false)
                return
            }

            self.log("Final fitness: \(results.finalFitness * 100)%")
            self.callback(true)
        }
    }
}

let fontOptimizer = FontOptimizer()

if CommandLine.arguments.count < 4 {
    printUsage()
    exit(EXIT_FAILURE)
}

var i = 1
while i < CommandLine.arguments.count {
    // FIXME: Consider adding arguments for number of concurrent iterations, and which GPU to use
    if CommandLine.arguments[i] == "--iterations" {
        i += 1
        if i >= CommandLine.arguments.count {
            printUsage()
            exit(EXIT_FAILURE)
        }
        guard let iterations = Int(CommandLine.arguments[i]) else {
            printUsage()
            exit(EXIT_FAILURE)
        }
        fontOptimizer.iterations = iterations
    } else if CommandLine.arguments[i] == "--fontIndex" {
        i += 1
        if i >= CommandLine.arguments.count {
            printUsage()
            exit(EXIT_FAILURE)
        }
        guard let fontIndex = Int(CommandLine.arguments[i]) else {
            printUsage()
            exit(EXIT_FAILURE)
        }
        fontOptimizer.fontIndex = fontIndex
    } else if CommandLine.arguments[i] == "--sampleSize" {
        i += 1
        if i >= CommandLine.arguments.count {
            printUsage()
            exit(EXIT_FAILURE)
        }
        guard let sampleSize = Int(CommandLine.arguments[i]) else {
            printUsage()
            exit(EXIT_FAILURE)
        }
        fontOptimizer.sampleSize = sampleSize
    } else if CommandLine.arguments[i] == "--roundTripURL" {
        i += 1
        if i >= CommandLine.arguments.count {
            printUsage()
            exit(EXIT_FAILURE)
        }
        guard let roundTripURL = URL(string: CommandLine.arguments[i]) else {
            printUsage()
            exit(EXIT_FAILURE)
        }
        fontOptimizer.roundTripURL = roundTripURL
    } else if CommandLine.arguments[i] == "--roundTripTrials" {
        i += 1
        if i >= CommandLine.arguments.count {
            printUsage()
            exit(EXIT_FAILURE)
        }
        guard let roundTripTrials = Int(CommandLine.arguments[i]) else {
            printUsage()
            exit(EXIT_FAILURE)
        }
        fontOptimizer.roundTripTrials = roundTripTrials
    } else if CommandLine.arguments[i] == "--roundTripStartupCostInBytes" {
        i += 1
        if i >= CommandLine.arguments.count {
            printUsage()
            exit(EXIT_FAILURE)
        }
        guard let roundTripStartupCostInBytes = Int(CommandLine.arguments[i]) else {
            printUsage()
            exit(EXIT_FAILURE)
        }
        fontOptimizer.roundTripStartupCostInBytes = roundTripStartupCostInBytes
    } else if CommandLine.arguments[i] == "--seedCount" {
        i += 1
        if i >= CommandLine.arguments.count {
            printUsage()
            exit(EXIT_FAILURE)
        }
        guard let seedCount = Int(CommandLine.arguments[i]) else {
            printUsage()
            exit(EXIT_FAILURE)
        }
        fontOptimizer.seedCount = seedCount
    } else if CommandLine.arguments[i] == "--silent" {
        fontOptimizer.silent = true
    } else if fontOptimizer.corpusFile == nil {
        fontOptimizer.corpusFile = CommandLine.arguments[i]
    } else if fontOptimizer.inputFile == nil {
        fontOptimizer.inputFile = CommandLine.arguments[i]
    } else if fontOptimizer.outputFile == nil {
        fontOptimizer.outputFile = CommandLine.arguments[i]
    } else {
        printUsage()
        exit(EXIT_FAILURE)
    }
    i += 1
}

var done = false
fontOptimizer.callback = {(success: Bool) in
    if !success {
        print("Failed!")
    } else {
        print("Succeeded!")
    }
    if !done {
        CFRunLoopStop(CFRunLoopGetMain())
    }
    done = true
}

guard fontOptimizer.isConfigured else {
    printUsage()
    exit(EXIT_FAILURE)
}

fontOptimizer.optimize()

if !done {
    CFRunLoopRun()
}
