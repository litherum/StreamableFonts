//
//  main.swift
//  Cost
//
//  Created by Myles C. Maxfield on 4/8/19.
//  Copyright © 2019 Myles C. Maxfield. All rights reserved.
//

import Foundation
import simd

struct CharacterOrderPair {
    var character: String
    var position: Float
}

var characterOrderPairs = [CharacterOrderPair]()

let chineseWebsiteScoresData = try! Data(contentsOf: URL(fileURLWithPath: "/Users/mmaxfield/tmp/ChineseWebsiteScores.plist"))
let scores = try! PropertyListSerialization.propertyList(from: chineseWebsiteScoresData, options: PropertyListSerialization.ReadOptions(), format: nil) as! [[String : Any]]
let scoreCount = scores.count

let positionsData = try! Data(contentsOf: URL(fileURLWithPath: "/Users/mmaxfield/tmp/positions.data"))
var positions = [Float]()
positionsData.withUnsafeBytes {(unsafeRawBufferPointer) in
    let boundMemory = unsafeRawBufferPointer.bindMemory(to: float4.self) // UnsafeBufferPointer<float4>
    assert(boundMemory.count == scoreCount * 2)
    for i in 0 ..< scoreCount {
        characterOrderPairs.append(CharacterOrderPair(character: scores[i]["Probe"] as! String, position: boundMemory[i * 2].x))
    }
}

characterOrderPairs.sort {(left, right) -> Bool in
    return left.position < right.position
}

var reverseMap = [String : Int]()
for i in 0 ..< characterOrderPairs.count {
    let characterOrderPair = characterOrderPairs[i]
    //print("\(characterOrderPair.character)")
    reverseMap[characterOrderPair.character] = i
}

let websitesData = try! Data(contentsOf: URL(fileURLWithPath: "/Users/mmaxfield/tmp/ChineseWebsites.plist"))
let websites = try! PropertyListSerialization.propertyList(from: websitesData, options: PropertyListSerialization.ReadOptions(), format: nil) as! [[String : String]]
var saved = 0
var possibleMiss = 0
for website in websites {
    var hitTest = [Bool](repeating: false, count: scoreCount)
    for character in website["Result"]! {
        let string = String(character)
        if let index = reverseMap[string] {
            hitTest[index] = true
        }
    }
    for v in hitTest {
        if !v {
            possibleMiss += 1
        }
    }
    var i = 0
    while i < scoreCount {
        let base = i
        while i < scoreCount && !hitTest[i] {
            i += 1
        }
        let miss = i - base
        while i < scoreCount && hitTest[i] {
            i += 1
        }
        if miss >= 8 {
            saved += miss - 8
        }
    }
}
print("Avoided downloading \(saved) characters out of a theoretically-possible \(possibleMiss) for a ratio of \(Double(saved) / Double(possibleMiss)).")
