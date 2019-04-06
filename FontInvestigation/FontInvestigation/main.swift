//
//  main.swift
//  FontInvestigation
//
//  Created by Myles C. Maxfield on 4/3/19.
//  Copyright © 2019 Myles C. Maxfield. All rights reserved.
//

import Foundation

func supportsJapanese(font: CTFont) -> Bool {
    let characters = [UniChar(0x306e)]
    var glyphs = [CGGlyph(0)]
    let success = CTFontGetGlyphsForCharacters(font, characters, &glyphs, 1)
    return success == true && glyphs[0] != CGGlyph(0)
}

func supportsKorean(font: CTFont) -> Bool {
    let characters = [UniChar(0xbc95)]
    var glyphs = [CGGlyph(0)]
    let success = CTFontGetGlyphsForCharacters(font, characters, &glyphs, 1)
    return success == true && glyphs[0] != CGGlyph(0)
}

func supportsChinese(font: CTFont) -> Bool {
    let characters = [UniChar(0x6c34)]
    var glyphs = [CGGlyph(0)]
    let success = CTFontGetGlyphsForCharacters(font, characters, &glyphs, 1)
    return success == true && glyphs[0] != CGGlyph(0)
}

struct Sizes {
    var total: Int
    var outlines: Int
}

func computeSizes(font: CTFont) -> Sizes {
    let availableTables = CTFontCopyAvailableTables(font, CTFontTableOptions())
    var outlines = 0
    var total = 0
    for i in 0 ..< CFArrayGetCount(availableTables) {
        let value = CFArrayGetValueAtIndex(availableTables, i)!
        let tag = CTFontTableTag(UnsafeRawPointer(bitPattern: 1)!.distance(to: value) + 1)
        let table = CTFontCopyTable(font, tag, CTFontTableOptions())! as Data
        if tag == kCTFontTableCFF || tag == kCTFontTableCFF2 || tag == kCTFontTableGlyf || tag == kCTFontTableLoca {
            outlines += table.count
        }
        total += table.count
    }
    return Sizes(total: total, outlines: outlines)
}

let fileManager = FileManager()
let base = "/Users/mmaxfield/src/GoogleFonts"
let enumerator = fileManager.enumerator(atPath: base)!
var chinese = 0
var korean = 0
var japanese = 0
var total = 0
while let partialPath = enumerator.nextObject() as? String {
    guard let fileAttributes = enumerator.fileAttributes else {
        continue
    }
    guard let type = fileAttributes[FileAttributeKey.type] as? FileAttributeType else {
        continue
    }
    guard type == FileAttributeType.typeRegular else {
        continue
    }
    let url = URL(fileURLWithPath: partialPath, relativeTo: URL(fileURLWithPath: base))
    guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as NSURL) as? [CTFontDescriptor] else {
        continue
    }
    guard descriptors.count > 0 else {
        continue
    }
    let descriptor = descriptors[0]
    let font = CTFontCreateWithFontDescriptor(descriptor, 48, nil)
    let name = CTFontCopyName(font, kCTFontPostScriptNameKey)!
    let fileSize = try! Data(contentsOf: url).count
    total += 1
    var isCJK = false
    var isChinese = false
    if supportsChinese(font: font) {
        chinese += 1
        isCJK = true
        isChinese = true
    }
    if supportsKorean(font: font) {
        korean += 1
        isCJK = true
    }
    if supportsJapanese(font: font) {
        japanese += 1
        isCJK = true
    }

    let sizes = computeSizes(font: font)

    let glyphCount = CTFontGetGlyphCount(font)

    if isChinese {
        print("\(name)\t\(url.absoluteString)\t\(sizes.total)\t\(glyphCount)")
    }
}

print("Chinese: \(chinese) Korean: \(korean) Japanese: \(japanese) Total: \(total)")
