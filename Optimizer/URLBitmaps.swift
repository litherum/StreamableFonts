//
//  URLBitmaps.swift
//  Optimizer
//
//  Created by Myles C. Maxfield on 5/10/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

import Foundation
import Metal

fileprivate func createBitmaps(glyphCount: Int, requiredGlyphs: [Set<CGGlyph>]) -> [Data] {
    var result = [Data]()
    for resource in requiredGlyphs {
        var data = Data(count: (glyphCount + 7) / 8)
        for glyph in resource {
            let byteIndex = Int(glyph / 8)
            let bitIndex = Int(glyph % 8)
            data[byteIndex] = data[byteIndex] | (1 << bitIndex)
        }
        result.append(data)
    }
    return result
}

internal struct URLBitmapsBuffer {
    let buffer: MTLBuffer
    let glyphBitfieldSize: Int
}

internal func createURLBitmapsBuffer(glyphCount: Int, requiredGlyphs: [Set<CGGlyph>], device: MTLDevice) -> URLBitmapsBuffer? {
    var urlBitmapsData = Data()
    var glyphBitfieldSize: Int?
    for bitmap in createBitmaps(glyphCount: glyphCount, requiredGlyphs: requiredGlyphs) {
        if glyphBitfieldSize == nil {
            glyphBitfieldSize = bitmap.count
        } else {
            assert(glyphBitfieldSize! == bitmap.count)
        }
        urlBitmapsData.append(bitmap)
    }
    guard glyphBitfieldSize != nil else {
        return nil
    }

    let buffer = urlBitmapsData.withUnsafeBytes {(unsafeRawBufferPointer: UnsafeRawBufferPointer) -> MTLBuffer? in
        return device.makeBuffer(bytes: unsafeRawBufferPointer.baseAddress!, length: unsafeRawBufferPointer.count, options: .storageModeManaged)
    }
    guard buffer != nil else {
        return nil
    }

    return URLBitmapsBuffer(buffer: buffer!, glyphBitfieldSize: glyphBitfieldSize!)
}
