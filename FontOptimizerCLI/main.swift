//
//  main.swift
//  FontOptimizerCLI
//
//  Created by Myles C. Maxfield on 4/9/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

import Foundation
import Metal
import Optimizer

/*fileprivate func chineseSystemFont() -> CTFont? {
    guard let font = CTFontCreateUIFontForLanguage(.system, 0, "zh-Hans" as NSString) else {
        return nil
    }
    let attributedString = NSAttributedString(string: "國", attributes: [kCTFontAttributeName as NSAttributedString.Key : font])
    let line = CTLineCreateWithAttributedString(attributedString)
    guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else {
        return nil
    }
    guard runs.count == 1 else {
        return nil
    }
    let run = runs[0]
    let attributes = CTRunGetAttributes(run) as NSDictionary
    guard let usedFontObject = attributes[kCTFontAttributeName] else {
        return nil
    }
    let usedFont = usedFontObject as! CTFont
    return usedFont
}

guard let font = chineseSystemFont() else {
    fatalError("Cannot create font")
}
guard let glyphSizes = computeGlyphSizes(font: font) else {
    fatalError("Cannot compute glyph sizes")
}
let totalGlyphSize = glyphSizes.glyphSizes.reduce(0, +)

var seed = [Int]()
for i in 0 ..< glyphSizes.glyphSizes.count {
    seed.append(i)
}

let data = try! Data(contentsOf: URL.init(fileURLWithPath: "/Users/mmaxfield/Library/Mobile Documents/com~apple~CloudDocs/Documents/apache-nutch-1.16/output.json"))
let jsonData = try! JSONSerialization.jsonObject(with: data) as! [Any]
let urlContents = jsonData.map { ($0 as! NSDictionary)["Contents"] as! String }
var requiredGlyphs = Array(repeating: Set<CGGlyph>(), count: urlContents.count)
var count = 0
let operationQueue = computeRequiredGlyphs(font: font, urlContents: urlContents) {(index, s) in
    guard let set = s else {
        fatalError("Could not compute required glyphs")
    }
    requiredGlyphs[index] = set
}
operationQueue.waitUntilAllOperationsAreFinished()

class MyOptimizerDelegate : OptimizerDelegate {
    func prepared(success: Bool) {
    
    }

    func report(fitness: Float) {
    
    }
}
let myOptimizerDelegate = MyOptimizerDelegate()

func performOptimization(roundTripCost: Double, glyphSizes: GlyphSizes) {
    guard let device = MTLCreateSystemDefaultDevice() else {
        fatalError("Could not create Metal device")
    }
    /*guard let optimizer = Optimizer(glyphSizes: glyphSizes.glyphSizes, requiredGlyphs: requiredGlyphs, seeds: [seed], threshold: Int(roundTripCost), unconditionalDownloadSize: glyphSizes.fontSize - totalGlyphSize, fontSize: glyphSizes.fontSize, device: device, delegate: myOptimizerDelegate) else {
        fatalError("Could not create optimizer")
    }
    optimizer.prepare()*/
}

class MeasurerDelegate : RoundTripTimeMeasurerDelegate {
    let trials = 100
    var count = 0
    var samples = [Sample]()

    func prepared(length: Int?) {
        print("Prepared.")
    }

    func producedSample(sample s: Sample?) {
        if let sample = s {
            samples.append(sample)
            print("Received sample \(count) of \(trials).")
        } else {
            print("Sample \(count) of \(trials) failure.")
        }
        count += 1
        if count == trials {
            if let roundTripCost = RoundTripTimeMeasurer.calculateRoundTripOverheadInBytes(samples: samples) {
                print("Round trip cost: \(roundTripCost) bytes")
                performOptimization(roundTripCost: roundTripCost, glyphSizes: glyphSizes)
            } else {
                print("Error calculating round trip cost")
            }
        }
    }
}

/*let measurerDelegate = MeasurerDelegate()
let measurer = RoundTripTimeMeasurer(url: URL(string: "https://fonts.gstatic.com/s/notosanssc/v11/k3kXo84MPvpLmixcA63oeALhLIiP-Q-87KaAaH7rzeAODp22mF0qmF4CSjmPC6A0Rg5g1igg1w.4.woff2")!, trials: 100, delegate: measurerDelegate)
measurer.measure()

RunLoop.main.run()*/
*/

// public func reorderFont(inputFilename: String, fontNumber: Optional<Int>, glyphOrder: [Int], outputFilename: String) -> Bool {

var order = Array(repeating: 0, count: 223)
for i in 0 ..< 223 {
    order[i] = 223 - i - 1
}

let result = Optimizer.reorderFont(inputFilename: "/Users/mmaxfield/tmp/archerssm-400-normal.otf", fontNumber: nil, glyphOrder: order, outputFilename: "/Users/mmaxfield/tmp/reordered.otf")
print("\(result)")
