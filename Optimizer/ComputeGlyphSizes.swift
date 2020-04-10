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

public class GlyphSizes: NSObject {
    public let fontSize: Int
    public let glyphSizes: [Int]

    init(fontSize: Int, glyphSizes: [Int]) {
        self.fontSize = fontSize
        self.glyphSizes = glyphSizes
    }
}

public func computeGlyphSizes(font: CTFont) -> GlyphSizes? {
    guard let tables = CTFontCopyAvailableTables(font, []) else {
        return nil
    }
    var fontSize = 0
    var glyphSizes = [Int]()
    var foundGlyphTable = false
    for i in 0 ..< CFArrayGetCount(tables) {
        let tag = CFArrayGetValueAtIndex(tables, i) - UnsafeRawPointer(bitPattern: 1)! + 1
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
        }
    }
    guard foundGlyphTable else {
        return nil
    }
    return GlyphSizes(fontSize: fontSize, glyphSizes: glyphSizes)
}
