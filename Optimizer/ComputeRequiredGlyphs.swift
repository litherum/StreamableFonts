//
//  ComputeRequiredGlyphs.swift
//  Optimizer
//
//  Created by Myles C. Maxfield on 4/9/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

import Foundation
import CoreText

public func computeRequiredGlyphs(font: CTFont, urlContents: [String], callback: @escaping (Int, Set<CGGlyph>?) -> Void) -> OperationQueue {
    let operationQueue = OperationQueue()
    for i in 0 ..< urlContents.count {
        operationQueue.addOperation {
            let contents = urlContents[i]
            let attributedString = NSAttributedString(string: contents, attributes: [kCTFontAttributeName as NSAttributedString.Key : font])
            let line = CTLineCreateWithAttributedString(attributedString)
            guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else {
                callback(i, nil)
                return
            }
            var set = Set<CGGlyph>()
            for run in runs {
                let attributes = CTRunGetAttributes(run) as NSDictionary
                guard let usedFontObject = attributes[kCTFontAttributeName] else {
                    callback(i, nil)
                    return
                }
                let usedFont = usedFontObject as! CTFont
                guard usedFont == font else {
                    continue
                }
                var glyphs = [CGGlyph](repeating: CGGlyph(), count: CTRunGetGlyphCount(run))
                CTRunGetGlyphs(run, CFRangeMake(0, CTRunGetGlyphCount(run)), &glyphs)
                set = set.union(glyphs.filter {$0 != 0xFFFF})
            }
            callback(i, set)
        }
    }
    return operationQueue
}
