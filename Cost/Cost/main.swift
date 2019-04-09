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

let websitesData = try! Data(contentsOf: URL(fileURLWithPath: "/Users/mmaxfield/tmp/ChineseWebsites.plist"))
let websites = try! PropertyListSerialization.propertyList(from: websitesData, options: PropertyListSerialization.ReadOptions(), format: nil) as! [[String : String]]

do {
    var union = Set<String>()
    for score in scores {
        union.insert(score["Probe"]! as! String)
    }
    var dict = [String : Int]()
    for u in union {
        dict[u] = 0
    }
    for website in websites {
        for c in website["Result"]! {
            if let v = dict[String(c)] {
                dict[String(c)] = v + 1
            }
        }
    }
    characterOrderPairs = []
    for d in dict {
        characterOrderPairs.append(CharacterOrderPair(character: d.key, position: Float(d.value)))
    }
}

characterOrderPairs.sort {(left, right) -> Bool in
    return left.position < right.position
}

do {
    var dict = [String : Bool]()
    for score in scores {
        dict[score["Probe"]! as! String] = false
    }
    var seed = characterOrderPairs[characterOrderPairs.count - 1].character
    characterOrderPairs = []
    while true {
        dict[seed] = true
        characterOrderPairs.append(CharacterOrderPair(character: seed, position: 0))
        var index: Int!
        for i in 0 ..< scores.count {
            if scores[i]["Probe"]! as! String == seed {
                index = i
                break
            }
        }
        assert(index != nil)
        let row = scores[index]["Candidates"] as! [[String : Any]]
        var best: Double!
        var bestCandidate = ""
        for i in 0 ..< row.count {
            guard dict[row[i]["Candidate"] as! String] == false else {
                continue
            }
            let s = row[i]["Score"] as! Double
            if best == nil || s > best {
                best = s
                bestCandidate = row[i]["Candidate"] as! String
            }
        }
        if best == nil {
            break
        }
        seed = bestCandidate
    }
    assert(characterOrderPairs.count == scores.count)
}

/*for _ in 0 ..< characterOrderPairs.count {
    for _ in 0 ..< characterOrderPairs.count {
        characterOrderPairs.swapAt(Int.random(in: 0 ..< characterOrderPairs.count), Int.random(in: 0 ..< characterOrderPairs.count))
    }
}*/

var reverseMap = [String : Int]()
for i in 0 ..< characterOrderPairs.count {
    let characterOrderPair = characterOrderPairs[i]
    //print("\(characterOrderPair.character)")
    reverseMap[characterOrderPair.character] = i
}

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
