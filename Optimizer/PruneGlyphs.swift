//
//  PruneGlyphs.swift
//  Optimizer
//
//  Created by Myles C. Maxfield on 6/3/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

import Foundation

public struct PrunedGlyphs {
    public let glyphMapping: [CGGlyph?] // glyphMapping[nonPrunedGlyph] = prunedGlyph
    public let reverseGlyphMapping: [CGGlyph] // glyphMapping[prunedGlyph] = nonPrunedGlyph
    public let glyphSizes: GlyphSizes
    public let requiredGlyphs: [Set<CGGlyph>]
}

public func pruneGlyphs(glyphSizes: GlyphSizes, requiredGlyphs: [Set<CGGlyph>]) -> PrunedGlyphs {
    var set = Set<CGGlyph>()
    for glyphs in requiredGlyphs {
        set = set.union(glyphs)
    }

    var glyphMapping: [CGGlyph?] = Array(repeating: nil, count: glyphSizes.glyphSizes.count)
    var reverseGlyphMapping = [CGGlyph]()
    for i in 0 ..< glyphSizes.glyphSizes.count {
        if set.contains(CGGlyph(i)) {
            glyphMapping[i] = CGGlyph(reverseGlyphMapping.count)
            reverseGlyphMapping.append(CGGlyph(i))
        }
    }

    var newGlyphSizes = Array(repeating: 0, count: Int(reverseGlyphMapping.count))
    for i in 0 ..< glyphSizes.glyphSizes.count {
        guard let mappedGlyph = glyphMapping[i] else {
            continue
        }
        newGlyphSizes[Int(mappedGlyph)] = glyphSizes.glyphSizes[i]
    }
    let prunedGlyphSizes = GlyphSizes(fontSize: glyphSizes.fontSize, glyphSizes: newGlyphSizes)

    var prunedRequiredGlyphs = [Set<CGGlyph>]()
    for glyphs in requiredGlyphs {
        let newSet = Set<CGGlyph>(glyphs.map { glyphMapping[Int($0)]! })
        prunedRequiredGlyphs.append(newSet)
    }

    return PrunedGlyphs(glyphMapping: glyphMapping, reverseGlyphMapping: reverseGlyphMapping, glyphSizes: prunedGlyphSizes, requiredGlyphs: prunedRequiredGlyphs)
}
