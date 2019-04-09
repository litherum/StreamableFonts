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

var frequencyOrder = characterOrderPairs.map {(characterOrderPair) in
    return characterOrderPair.character
}
frequencyOrder.reverse()

do {
    characterOrderPairs = []
    var dict = [String : Bool]()
    for score in scores {
        dict[score["Probe"]! as! String] = false
    }

    var asdf = [CharacterOrderPair]()
    var m = [String : [String : Double]]()
    for score in scores {
        var row = [String : Double]()
        for s in score["Candidates"]! as! [[String : Any]] {
            let t = s["Score"]! as! Double
            row[s["Candidate"]! as! String] = t
            if !t.isNaN {
                asdf.append(CharacterOrderPair(character: score["Probe"]! as! String, position: Float(t)))
            }
        }
        m[score["Probe"]! as! String] = row
    }
    asdf.sort {(left, right) -> Bool in
        return left.position > right.position
    }
    for asdfasdf in asdf {
        if dict[asdfasdf.character]! == false {
            characterOrderPairs.append(CharacterOrderPair(character: asdfasdf.character, position: 0))
            dict[asdfasdf.character] = true
        }
    }
    for k in dict {
        if k.value == false {
            characterOrderPairs.insert(CharacterOrderPair(character: k.key, position: 0), at: 0)
        }
    }
    assert(characterOrderPairs.count == scores.count)

    /*characterOrderPairs = []
    var workList = [CharacterOrderPair]()
    var workMap = [String : Float]()
    workList.append(CharacterOrderPair(character: frequencyOrder[0], position: 0))
    workMap[frequencyOrder[0]] = 0
    while !workList.isEmpty {
        let item = workList[0]
        workList.remove(at: 0)
        workMap.removeValue(forKey: item.character)
        if dict[item.character]! == true {
            continue
        }
        characterOrderPairs.append(CharacterOrderPair(character: item.character, position: 0))
        print("\(characterOrderPairs.count)")
        dict[item.character] = true
        for k in m[item.character]! {
            if dict[k.key]! == false && !k.value.isNaN && (workMap[k.key] == nil || workMap[k.key]! < Float(k.value)) {
                workList.append(CharacterOrderPair(character: k.key, position: Float(k.value)))
                workMap[k.key] = Float(k.value)
            }
        }
        workList.sort {(left, right) -> Bool in
            return left.position > right.position
        }
        if workList.isEmpty && characterOrderPairs.count != scores.count {
            for f in frequencyOrder {
                if dict[f] == false {
                    workList.append(CharacterOrderPair(character: f, position: 0))
                    workMap[f] = 0
                    break
                }
            }
        }
    }
    assert(characterOrderPairs.count == scores.count)*/
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
