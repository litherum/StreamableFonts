//
//  PruneGlyphs.swift
//  Optimizer
//
//  Created by Myles C. Maxfield on 6/3/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

import Foundation

public struct PrunedGlyphs {
    public let glyphMapping: [CGGlyph]
    public let glyphSizes: GlyphSizes
    public let requiredGlyphs: [Set<CGGlyph>]
}

public func pruneGlyphs(glyphSizes: GlyphSizes, requiredGlyphs: [Set<CGGlyph>]) -> PrunedGlyphs {
    var set = Set<CGGlyph>()
    for glyphs in requiredGlyphs {
        set = set.union(glyphs)
    }

    var glyphMapping = Array(repeating: CGGlyph(0), count: glyphSizes.glyphSizes.count)
    var newIndex = CGGlyph(1)
    for i in 1 ..< glyphSizes.glyphSizes.count {
        if set.contains(CGGlyph(i)) {
            glyphMapping[i] = newIndex
            newIndex += 1
        }
    }

    var newGlyphSizes = Array(repeating: 0, count: Int(newIndex))
    newGlyphSizes[0] = glyphSizes.glyphSizes[0]
    for i in 1 ..< glyphSizes.glyphSizes.count {
        if glyphMapping[i] != 0 {
            newGlyphSizes[Int(glyphMapping[i])] = glyphSizes.glyphSizes[i]
        }
    }
    let prunedGlyphSizes = GlyphSizes(fontSize: glyphSizes.fontSize, glyphSizes: newGlyphSizes)

    var prunedRequiredGlyphs = [Set<CGGlyph>]()
    for glyphs in requiredGlyphs {
        let newSet = Set<CGGlyph>(glyphs.map { glyphMapping[Int($0)] })
        prunedRequiredGlyphs.append(newSet)
    }

    return PrunedGlyphs(glyphMapping: glyphMapping, glyphSizes: prunedGlyphSizes, requiredGlyphs: prunedRequiredGlyphs)
}
