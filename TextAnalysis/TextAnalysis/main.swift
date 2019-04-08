//
//  main.swift
//  TextAnalysis
//
//  Created by Myles C. Maxfield on 4/4/19.
//  Copyright © 2019 Myles C. Maxfield. All rights reserved.
//

import Foundation
import AppKit

let data = try! Data(contentsOf: URL(fileURLWithPath: "/Users/litherum/tmp/ChineseWebsites.plist"))
guard let plist = try!PropertyListSerialization.propertyList(from: data, options: PropertyListSerialization.ReadOptions(), format: nil) as? [[String : String]] else {
    fatalError()
}

let strings = plist.map {(dictionary) -> String in
    return dictionary["Result"]!
}

let sets = strings.map {(string) -> Set<Character> in
    var set = Set<Character>()
    for character in string {
        set.insert(character)
    }
    return set
}

guard let fontDescriptors = CTFontManagerCreateFontDescriptorsFromURL(URL(fileURLWithPath: "/Users/litherum/src/GoogleFonts/ofl/mplus1p/Mplus1p-Regular.ttf") as NSURL) as? [CTFontDescriptor] else {
    fatalError()
}
let fontDescriptor = fontDescriptors[0]
let font = CTFontCreateWithFontDescriptor(fontDescriptor, 48, nil)

var union = Set<Character>()
for set in sets {
    for character in set {
        if union.contains(character) {
            continue
        }
        let attributedString = NSAttributedString(string: String(character), attributes: [NSAttributedString.Key.font : font])
        let line = CTLineCreateWithAttributedString(attributedString)
        let runs = CTLineGetGlyphRuns(line) as! [CTRun]
        var success = true
        for run in runs {
            let attributes = CTRunGetAttributes(run) as NSDictionary
            let usedFont = attributes[kCTFontAttributeName] as! CTFont
            if usedFont != font {
                success = false
                break
            }
        }
        if success {
            union.insert(character)
        }
    }
    print("Union size: \(union.count)")
}

print("Union count: \(union.count)")

var scores = [[String : Any]]()

var index = 0
var allBuddyScores = [[Double]]()
for probe in union {
    var buddyScore = Double(-1)
    var bestBuddy: Character?
    var candidateScores = [[String : Any]]()
    var buddyScores = [Double]()
    for candidate in union {
        guard probe != candidate else {
            continue
        }
        var both = 0
        var neither = 0
        var has1 = 0
        var has2 = 0
        for set in sets {
            if set.contains(probe) && set.contains(candidate) {
                both += 1
            } else if set.contains(probe) && !set.contains(candidate) {
                has1 += 1
            } else if !set.contains(probe) && set.contains(candidate) {
                has2 += 1
            } else {
                assert(!set.contains(probe) && !set.contains(candidate))
                neither += 1
            }
        }
        let probability1 = Double(both) / Double(both + has1)
        let probability2 = Double(neither) / Double(neither + has2)
        let probability = probability1 * probability2

        buddyScores.append(probability)

        var candidateScoreDictionary = [String : Any]()
        candidateScoreDictionary["Candidate"] = String(candidate)
        candidateScoreDictionary["Score"] = probability
        candidateScores.append(candidateScoreDictionary)
        if bestBuddy == nil || probability >= buddyScore {
            buddyScore = probability
            bestBuddy = candidate
        }
    }
    buddyScores.sort {(left, right) -> Bool in
        return left > right
    }
    allBuddyScores.append(buddyScores)
    var scoreDictionary = [String : Any]()
    scoreDictionary["Probe"] = String(probe)
    scoreDictionary["Candidates"] = candidateScores
    scores.append(scoreDictionary)
    print("\(index)\t\(probe)\t\(bestBuddy!)\t\(buddyScore)")
    index += 1
}
allBuddyScores.sort {(left, right) -> Bool in
    return left[0] < right[0]
}
print("Median buddy score: \(allBuddyScores[allBuddyScores.count / 2])")

let scoresData = try! PropertyListSerialization.data(fromPropertyList: scores, format: .xml, options: 0)
try! scoresData.write(to: URL(fileURLWithPath: "/Users/litherum/tmp/ChineseWebsiteScores.plist"))

/*let data = try! Data(contentsOf: URL(fileURLWithPath: "/Users/litherum/tmp/ChineseWebsiteScores.plist"))
let scores = try! PropertyListSerialization.propertyList(from: data, options: PropertyListSerialization.ReadOptions(), format: nil) as! [[String : Any]]*/

let particleCount = scores.count
var floatScores = [Float]()
for i in 0 ..< particleCount {
    print("Looking up \(i)")
    let scoresArray = scores[i]["Candidates"] as! [[String : Any]]
    var dict = [String : Float]()
    for score in scoresArray {
        dict[score["Candidate"] as! String] = Float(truncating: score["Score"] as! NSNumber)
    }
    for j in 0 ..< particleCount {
        let target = scores[j]["Probe"] as! String
        if let result = dict[target] {
            floatScores.append(result)
        } else {
            floatScores.append(0)
        }
    }
}
let floatScoresData = Data(bytes: &floatScores, count: MemoryLayout<Float>.size * floatScores.count)
try! floatScoresData.write(to: URL(fileURLWithPath: "/Users/litherum/tmp/ChineseWebsiteFloatScores.data"))
