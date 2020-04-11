//
//  ComputeGlyphSizes.swift
//  Optimizer
//
//  Created by Myles C. Maxfield on 4/9/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

import Foundation
import CoreText

fileprivate func read16BigEndian(data: Data) -> UInt16? {
    guard data.count >= 2 else {
        return nil
    }
    return (UInt16(data[0]) << 8) | (UInt16(data[1]) << 0)
}

fileprivate func read32BigEndian(data: Data) -> UInt32? {
    guard data.count >= 4 else {
        return nil
    }
    return (UInt32(data[0]) << 24) | (UInt32(data[1]) << 16) | (UInt32(data[2]) << 8) | (UInt32(data[3]) << 0)
}

fileprivate func readOffset(data: Data, index: Int, offsetSize: UInt8)-> UInt32? {
    var result = UInt32(0)
    var count = 0
    switch offsetSize {
        case 4:
            guard data.count >= index + 4 else {
                return nil
            }
            result = (result << 8) | UInt32(data[index + count])
            count += 1
            fallthrough
        case 3:
            guard data.count >= index + 3 else {
                return nil
            }
            result = (result << 8) | UInt32(data[index + count])
            count += 1
            fallthrough
        case 2:
            guard data.count >= index + 2 else {
                return nil
            }
            result = (result << 8) | UInt32(data[index + count])
            count += 1
            fallthrough
        case 1:
            guard data.count >= index + 1 else {
                return nil
            }
            result = (result << 8) | UInt32(data[index + count])
        default:
            return nil
    }
    return result
}

fileprivate func indexSize(indexData: Data) -> Int? {
    guard let count = read16BigEndian(data: indexData) else {
        return nil
    }
    guard count != 0 else {
        return 2
    }
    guard indexData.count >= 2 + 1 else {
        return nil
    }
    let offsetSize = indexData[2]
    var offset = UInt32(0)
    for i in 0 ..< Int(count) + 1 {
        let beginIndex = 2 + 1 + Int(offsetSize) * Int(i)
        guard let newOffset = readOffset(data: indexData, index: beginIndex, offsetSize: offsetSize) else {
            return nil
        }
        offset = newOffset
    }
    return 2 + 1 + Int(offsetSize) * (Int(count) + 1) + Int(offset) - 1
}

fileprivate func charStringsOffsetFromTopDict(dictData: Data) -> Int32? {
    var index = 0
    var value = Int32(0)
    repeat {
        let b0 = dictData[index]
        if (b0 >= 32 && b0 <= 246) {
            value = Int32(b0) - 139
            index += 1
        } else if (b0 >= 247 && b0 <= 250) {
            guard index + 1 < dictData.count else {
                return nil
            }
            value = (Int32(b0) - 247) * 256 + Int32(dictData[index + 1]) + 108
            index += 2
        } else if (b0 >= 251 && b0 <= 254) {
            guard index + 1 < dictData.count else {
                return nil
            }
            value = -(Int32(b0) - 251) * 256 - Int32(dictData[index + 1]) - 108
            index += 2
        } else if (b0 == 28) {
            guard index + 2 < dictData.count else {
                return nil
            }
            value = (Int32(dictData[index + 1]) << 8) | Int32(dictData[index + 2])
            index += 3
        } else if (b0 == 29) {
            guard index + 4 < dictData.count else {
                return nil
            }
            value = (Int32(dictData[index + 1]) << 24) | (Int32(dictData[index + 2]) << 16) | (Int32(dictData[index + 3]) << 8) | (Int32(dictData[index + 4]) << 0)
            index += 5
        } else if (b0 == 30) {
            // Real number operands are not implemented.
            return nil
        } else if ((b0 >= 22 && b0 <= 27) || b0 == 31 || b0 == 255) {
            // Reserved.
            return nil
        } else if (b0 == 12) {
            index += 2
        } else if (b0 == 17) {
            return value
        } else if (b0 >= 0 && b0 <= 21) {
            index += 1
        } else {
            return nil
        }
    } while (index < dictData.count)

    return nil
}

fileprivate func charStringsOffsetFromTopDictIndex(indexData: Data) -> Int32? {
    guard let count = read16BigEndian(data: indexData) else {
        return nil
    }
    guard count == 1 else {
        return nil
    }
    guard indexData.count >= 2 + 1 else {
        return nil
    }
    let offsetSize = indexData[2]
    let beginIndex = 2 + 1 + Int(offsetSize) * 2
    guard indexData.count >= beginIndex else {
        return nil
    }
    guard let offset = readOffset(data: indexData, index: 2 + 1 + Int(offsetSize), offsetSize: offsetSize) else {
        return nil
    }
    let dictSize = offset - 1
    let endIndex = Int(dictSize)
    guard indexData.count >= beginIndex && endIndex >= 0 && indexData.count >= beginIndex + endIndex else {
        return nil
    }
    return charStringsOffsetFromTopDict(dictData: indexData.subdata(in: beginIndex ..< endIndex))
}

fileprivate func glyphSizesCFF(cffTable: Data) -> [Int]? {
    // https://wwwimages2.adobe.com/content/dam/acom/en/devnet/font/pdfs/5176.CFF.pdf
    guard cffTable.count >= 4 else {
        return nil
    }

    let majorVersion = cffTable[0]
    guard majorVersion == 1 else {
        return nil
    }
    let headerSize = cffTable[2]

    // Name index
    guard cffTable.count >= Int(headerSize) else {
        return nil
    }
    guard let nameIndexSize = indexSize(indexData: cffTable.advanced(by: Int(headerSize))) else {
        return nil
    }

    // Top dict index
    guard cffTable.count >= Int(headerSize) + Int(nameIndexSize) + 2 + 1 else {
        return nil
    }
    guard let charStringsOffset = charStringsOffsetFromTopDictIndex(indexData: cffTable.advanced(by: Int(headerSize) + Int(nameIndexSize))) else {
        return nil
    }

    // CharStrings index
    guard cffTable.count >= Int(charStringsOffset) + 2 + 1 else {
        return nil
    }
    guard let glyphCount = read16BigEndian(data: cffTable.advanced(by: Int(charStringsOffset))) else {
        return nil
    }
    let offsetSize = cffTable[Int(charStringsOffset) + 2]
    guard cffTable.count >= Int(charStringsOffset) + 2 + 1 + Int(offsetSize) * (Int(glyphCount) + 1) else {
        return nil
    }
    var glyphSizes = [Int]()
    for i in 0 ..< Int(glyphCount) {
        guard let beginOffset = readOffset(data: cffTable, index: Int(charStringsOffset) + 2 + 1 + Int(offsetSize) * i, offsetSize: offsetSize) else {
            return nil
        }
        guard let endOffset = readOffset(data: cffTable, index: Int(charStringsOffset) + 2 + 1 + Int(offsetSize) * (i + 1), offsetSize: offsetSize) else {
            return nil
        }
        guard endOffset >= beginOffset else {
            return nil
        }
        glyphSizes.append(Int(endOffset) - Int(beginOffset))
    }
    return glyphSizes
}

fileprivate func resolve(index: Int, rawData: [Data], glyphSizes: inout [Int]) -> Bool {
    guard index < rawData.count else {
        return false
    }
    guard glyphSizes[index] == 0 else {
        return true
    }
    guard rawData[index].count > 0 else {
        glyphSizes[index] = 0
        return true
    }
    guard let numberOfContours = read16BigEndian(data: rawData[index]) else {
        return false
    }
    let signedNumberOfContours = Int16(bitPattern: numberOfContours)
    guard signedNumberOfContours < 0 else {
        // Single glyph
        glyphSizes[index] = rawData[index].count
        return true
    }
    // Compound glyph
    var i = 10
    var total = 0
    while true {
        guard let flags = read16BigEndian(data: rawData[index].advanced(by: i)) else {
            return false
        }
        guard let glyphIndex = read16BigEndian(data: rawData[index].advanced(by: i + 2)) else {
            return false
        }
        guard resolve(index: Int(glyphIndex), rawData: rawData, glyphSizes: &glyphSizes) else {
            return false
        }
        total += rawData[Int(glyphIndex)].count
        let words = flags & (1 << 0) != 0
        if words {
            i += 8
        } else {
            i += 6
        }
        if flags & (1 << 3) != 0 {
            i += 2
        }
        if flags & (1 << 6) != 0 {
            i += 4
        }
        if flags & (1 << 7) != 0 {
            i += 8
        }
        let more = flags & (0x1 << 5) != 0
        guard more else {
            break
        }
    }
    glyphSizes[index] = total
    return true
}

fileprivate func glyphSizesGlyf(glyfTable: Data, locaTable: Data, headTable: Data, glyphCount: Int) -> [Int]? {
    let indexToLocFormat = read16BigEndian(data: headTable.advanced(by: 50))
    guard indexToLocFormat == 0 || indexToLocFormat == 1 else {
        return nil
    }
    var rawData = [Data]()
    for i in 0 ..< glyphCount {
        var begin = 0
        var end = 0
        if indexToLocFormat == 0 {
            // Short offsets
            guard let beginOffset = read16BigEndian(data: locaTable.advanced(by: i * 2)) else {
                return nil
            }
            guard let endOffset = read16BigEndian(data: locaTable.advanced(by: (i + 1) * 2)) else {
                return nil
            }
            begin = Int(beginOffset) * 2
            end = Int(endOffset) * 2
        } else {
            guard let beginOffset = read32BigEndian(data: locaTable.advanced(by: i * 4)) else {
                return nil
            }
            guard let endOffset = read32BigEndian(data: locaTable.advanced(by: (i + 1) * 4)) else {
                return nil
            }
            begin = Int(beginOffset)
            end = Int(endOffset)
            guard begin <= end else {
                return nil
            }
        }
        rawData.append(glyfTable.subdata(in: begin ..< end))
    }

    var glyphSizes = Array(repeating: 0, count: glyphCount)
    for i in 0 ..< glyphCount {
        guard resolve(index: i, rawData: rawData, glyphSizes: &glyphSizes) else {
            return nil
        }
    }
    return glyphSizes
}

public class GlyphSizes: NSObject {
    public let fontSize: Int
    public let glyphSizes: [Int]

    public init(fontSize: Int, glyphSizes: [Int]) {
        self.fontSize = fontSize
        self.glyphSizes = glyphSizes
    }
}

public func computeGlyphSizes(font: CTFont) -> GlyphSizes? {
    let glyphCount = CTFontGetGlyphCount(font)
    guard let tables = CTFontCopyAvailableTables(font, []) else {
        return nil
    }
    var fontSize = 0
    var glyphSizes = [Int]()
    var foundGlyphTable = false
    for i in 0 ..< CFArrayGetCount(tables) {
        let tag = CFArrayGetValueAtIndex(tables, i) - UnsafeRawPointer(bitPattern: 1)! + 1
        /*let a = Character(Unicode.Scalar((tag & 0xFF000000) >> 24)!)
        let b = Character(Unicode.Scalar((tag & 0x00FF0000) >> 16)!)
        let c = Character(Unicode.Scalar((tag & 0x0000FF00) >>  8)!)
        let d = Character(Unicode.Scalar((tag & 0x000000FF) >>  0)!)
        print("\(a)\(b)\(c)\(d)")*/
        guard let cfTable = CTFontCopyTable(font, CTFontTableTag(tag), []) else {
            return nil
        }
        let table = cfTable as Data
        fontSize += table.count
        if tag == kCTFontTableCFF {
            if foundGlyphTable {
                return nil
            }
            guard let result = glyphSizesCFF(cffTable: table) else {
                return nil
            }
            glyphSizes = result
            foundGlyphTable = true
        } else if tag == kCTFontTableGlyf {
            if foundGlyphTable {
                return nil
            }
            guard let loca = CTFontCopyTable(font, CTFontTableTag(kCTFontTableLoca), []) else {
                return nil
            }
            guard let head = CTFontCopyTable(font, CTFontTableTag(kCTFontTableHead), []) else {
                return nil
            }
            guard let result = glyphSizesGlyf(glyfTable: table, locaTable: loca as Data, headTable: head as Data, glyphCount: glyphCount) else {
                return nil
            }
            glyphSizes = result
            foundGlyphTable = true
        }
    }
    guard foundGlyphTable else {
        return nil
    }
    return GlyphSizes(fontSize: fontSize, glyphSizes: glyphSizes)
}
