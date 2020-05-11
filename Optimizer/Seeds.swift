//
//  Seeds.swift
//  Optimizer
//
//  Created by Myles C. Maxfield on 5/10/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

import Foundation
import Metal

fileprivate struct FrequencyTuple {
    var frequency: Int
    let glyph: Int
}

public func frequencyOrder(glyphCount: Int, requiredGlyphs: [Set<CGGlyph>]) -> [Int] {
    var histogram = [FrequencyTuple]()
    for i in 0 ..< glyphCount {
        histogram.append(FrequencyTuple(frequency: 0, glyph: i))
    }
    for glyphs in requiredGlyphs {
        for glyph in glyphs {
            histogram[Int(glyph)].frequency += 1
        }
    }
    histogram.sort { $0.frequency > $1.frequency }
    return histogram.map { $0.glyph }
}

public func computeBigramScores(glyphCount: Int, requiredGlyphs: [Set<CGGlyph>], device: MTLDevice, callback: @escaping ([[Float]]?) -> Void) {
    guard let queue = device.makeCommandQueue(),
        let urlBitmapsBuffer = createURLBitmapsBuffer(glyphCount: glyphCount, requiredGlyphs: requiredGlyphs, device: device),
        let bigramScoresBuffer = device.makeBuffer(length: MemoryLayout<Float32>.stride * glyphCount * glyphCount, options: .storageModeManaged) else {
        callback(nil)
        return
    }

    let constantValues = MTLFunctionConstantValues()
    var glyphBitfieldSize = UInt32(urlBitmapsBuffer.glyphBitfieldSize)
    var glyphCount32 = UInt32(glyphCount)
    var urlCount = UInt32(requiredGlyphs.count)
    constantValues.setConstantValue(&glyphBitfieldSize, type: .uint, withName: "glyphBitfieldSize")
    constantValues.setConstantValue(&glyphCount32, type: .uint, withName: "glyphCount")
    constantValues.setConstantValue(&urlCount, type: .uint, withName: "urlCount")

    do {
        let library = try device.makeDefaultLibrary(bundle: Bundle(for: FontOptimizer.self))
        library.makeFunction(name: "computeBigramScores", constantValues: constantValues) {(computeBigramScoresFunction, error) in
            guard computeBigramScoresFunction != nil && error == nil else {
                callback(nil)
                return
            }

            let computePipelineDescriptor = MTLComputePipelineDescriptor()
            computePipelineDescriptor.computeFunction = computeBigramScoresFunction
            computePipelineDescriptor.buffers[0].mutability = .immutable
            computePipelineDescriptor.buffers[1].mutability = .mutable
            device.makeComputePipelineState(descriptor: computePipelineDescriptor, options: []) {(computePipelineState, reflection, error) in
                guard computePipelineState != nil && error == nil,
                    let commandBuffer = queue.makeCommandBuffer(),
                    let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder() else {
                    callback(nil)
                    return
                }
                computeCommandEncoder.setComputePipelineState(computePipelineState!)
                computeCommandEncoder.setBuffers([urlBitmapsBuffer.buffer, bigramScoresBuffer], offsets: [0, 0], range: 0 ..< 2)
                computeCommandEncoder.dispatchThreads(MTLSize(width: glyphCount, height: glyphCount, depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 32, depth: 1))
                computeCommandEncoder.endEncoding()
                guard let blitCommandEncoder = commandBuffer.makeBlitCommandEncoder() else {
                    callback(nil)
                    return
                }
                blitCommandEncoder.synchronize(resource: bigramScoresBuffer)
                blitCommandEncoder.endEncoding()
                commandBuffer.addCompletedHandler {(commandBuffer) in
                    let ptr = bigramScoresBuffer.contents().bindMemory(to: Float32.self, capacity: glyphCount * glyphCount)
                    var bigramScores = Array(repeating: Array(repeating: Float(), count: glyphCount), count: glyphCount)
                    for i in 0 ..< glyphCount {
                        for j in 0 ..< glyphCount {
                            bigramScores[i][j] = Float(ptr[i * glyphCount + j]) // FIXME: Is this right?
                        }
                    }
                    callback(bigramScores)
                }
                commandBuffer.commit()
            }
        }
    } catch {
        callback(nil)
        return
    }
}

fileprivate func seedGlyph(glyphCount: Int, bigramScores: [[Float]]) -> Int? {
    // There are probably a lot of 1.0 scores which tie for best.
    // We could be more sophisticated here and pick the glyph which is in the most number of documents, or something.
    var bestScore = Float(0)
    var bestGlyph = 0
    for i in 0 ..< glyphCount {
        for j in 0 ..< glyphCount {
            guard i != j else {
                continue
            }
            let score = bigramScores[i][j]
            if score >= bestScore {
                bestScore = score
                bestGlyph = i
            }
        }
    }
    return bestGlyph
}

public func lastBest(glyphCount: Int, bigramScores: [[Float]], progressCallback: @escaping () -> Void) -> [Int]? {
    var order = [Int]()
    var spent = Array(repeating: false, count: glyphCount)
    guard let start = seedGlyph(glyphCount: glyphCount, bigramScores: bigramScores) else {
        return nil
    }
    var currentGlyph = start
    for _ in 0 ..< glyphCount {
        order.append(currentGlyph)
        progressCallback()
        spent[currentGlyph] = true
        var bestScore = Float(0)
        var bestGlyph = 0
        for j in 0 ..< glyphCount {
            guard !spent[j] else {
                continue
            }
            let score = bigramScores[currentGlyph][j]
            if score >= bestScore {
                bestScore = score
                bestGlyph = j
            }
        }
        currentGlyph = bestGlyph
    }
    return order
}

public func placedBest(glyphCount: Int, bigramScores: [[Float]], progressCallback: @escaping () -> Void) -> [Int]? {
    var order = Array(repeating: 0, count: glyphCount)
    var candidates = Array(repeating: 0, count: glyphCount)
    for i in 0 ..< glyphCount {
        candidates[i] = i
    }
    guard let start = seedGlyph(glyphCount: glyphCount, bigramScores: bigramScores) else {
        return nil
    }
    var currentGlyph = start
    var candidateIndex = currentGlyph
    for i in 0 ..< glyphCount {
        order[i] = currentGlyph
        progressCallback()
        for j in candidateIndex ..< glyphCount - i - 1 {
            candidates[j] = candidates[j + 1]
        }
        var bestScore = Float(0)
        var bestGlyph = 0
        candidateIndex = 0
        for j in 0 ..< i + 1 {
            let placedGlyph = order[j]
            for k in 0 ..< glyphCount - i - 1 {
                let score = bigramScores[placedGlyph][candidates[k]]
                if score >= bestScore {
                    bestScore = score
                    bestGlyph = candidates[k]
                    candidateIndex = k
                }
            }
        }
        currentGlyph = bestGlyph
    }
    return order
}

public func generateRandomSeeds(glyphCount: Int, seedCount: Int) -> [[Int]] {
    var seeds = [[Int]]()
    for _ in 0 ..< seedCount {
        var candidates = [Int]()
        for i in 0 ..< glyphCount {
            candidates.append(i)
        }
        var order = [Int]()
        for _ in 0 ..< glyphCount {
            let index = Int(arc4random_uniform(UInt32(candidates.count)))
            order.append(candidates[index])
            candidates.remove(at: index)
        }
        seeds.append(order)
    }
    return seeds
}
