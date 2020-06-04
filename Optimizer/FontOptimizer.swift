//
//  FontOptimizer.swift
//  Optimizer
//
//  Created by Myles C. Maxfield on 4/9/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

import Foundation
import Metal

public struct OptimizerResults {
    public let glyphOrder: [Int]
    public let finalFitness: Float
}

public protocol FontOptimizerDelegate : class {
    func prepared(success: Bool)
    func report(fitness: Float)
    func stopped(results: OptimizerResults?)
}

public class FontOptimizer {
    let glyphSizes: [Int]
    let requiredGlyphs: [Set<CGGlyph>]
    let seeds: [[Int]]
    let threshold: Int
    let unconditionalDownloadSize: Int
    let fontSize: Int
    let iterationCount: Int?
    var iterationIndex: Int?
    let device: MTLDevice
    let queue: MTLCommandQueue
    var fitnessFunction: MTLFunction!
    var sumFitnessesFunction: MTLFunction!
    var swapGlyphsFunction: MTLFunction!
    var annealFunction: MTLFunction!
    var fitnessState: MTLComputePipelineState!
    var sumFitnessesState: MTLComputePipelineState!
    var swapGlyphsState: MTLComputePipelineState!
    var annealState: MTLComputePipelineState!
    var generationBuffer: MTLBuffer!
    var glyphSizesBuffer: MTLBuffer!
    var urlBitmapsBuffer: MTLBuffer!
    var fitnessesPerURLBuffer: MTLBuffer!
    var fitnessABuffer: MTLBuffer!
    var fitnessBBuffer: MTLBuffer!
    var fitnessMonitorABuffer: MTLBuffer!
    var fitnessMonitorBBuffer: MTLBuffer!
    weak var delegate: FontOptimizerDelegate?
    var glyphCount: Int {
        get {
            return glyphSizes.count
        }
    }
    var glyphBitfieldSize = 0
    var urlCount: Int {
        get {
            return requiredGlyphs.count
        }
    }
    var generationSize: Int {
        get {
            return seeds.count
        }
    }
    let inFlight = 10
    var monitoring = false
    var stopCount = 0
    var stopping = false
    var state = false

    public init?(glyphSizes: [Int], requiredGlyphs: [Set<CGGlyph>], seeds: [[Int]], threshold: Int, unconditionalDownloadSize: Int, fontSize: Int, device: MTLDevice, iterationCount: Int?, delegate: FontOptimizerDelegate) {
        for seed in seeds {
            if seed.count != glyphSizes.count {
                return nil
            }
        }
        for resource in requiredGlyphs {
            for glyph in resource {
                if glyph >= glyphSizes.count {
                    return nil
                }
            }
        }

        self.glyphSizes = glyphSizes;
        self.requiredGlyphs = requiredGlyphs
        self.seeds = seeds;
        self.threshold = threshold
        self.unconditionalDownloadSize = unconditionalDownloadSize
        self.fontSize = fontSize
        self.device = device
        self.iterationCount = iterationCount
        self.delegate = delegate

        guard let queue = device.makeCommandQueue() else {
            return nil
        }
        self.queue = queue
    }

    private func loadShaders(callback: @escaping (Bool) -> Void) {
        let constantValues = MTLFunctionConstantValues()
        var glyphBitfieldSize = UInt32(self.glyphBitfieldSize)
        var glyphCount = UInt32(self.glyphCount)
        var urlCount = UInt32(self.urlCount)
        var threshold = UInt32(self.threshold)
        var unconditionalDownloadSize = UInt32(self.unconditionalDownloadSize)
        var fontSize = UInt32(self.fontSize)
        constantValues.setConstantValue(&glyphBitfieldSize, type: .uint, withName: "glyphBitfieldSize")
        constantValues.setConstantValue(&glyphCount, type: .uint, withName: "glyphCount")
        constantValues.setConstantValue(&urlCount, type: .uint, withName: "urlCount")
        constantValues.setConstantValue(&threshold, type: .uint, withName: "threshold")
        constantValues.setConstantValue(&unconditionalDownloadSize, type: .uint, withName: "unconditionalDownloadSize")
        constantValues.setConstantValue(&fontSize, type: .uint, withName: "fontSize")

        do {
            let library = try device.makeDefaultLibrary(bundle: Bundle(for: FontOptimizer.self))
            library.makeFunction(name: "fitness", constantValues: constantValues) {(function, error) in
                guard function != nil && error == nil else {
                    callback(false)
                    return
                }

                self.fitnessFunction = function

                library.makeFunction(name: "sumFitnesses", constantValues: constantValues) {(function, error) in
                    guard function != nil && error == nil else {
                        callback(false)
                        return
                    }

                    self.sumFitnessesFunction = function
                    
                    library.makeFunction(name: "swapGlyphs", constantValues: constantValues) {(function, error) in
                        guard function != nil && error == nil else {
                            callback(false)
                            return
                        }
    
                        self.swapGlyphsFunction = function
                    
                        library.makeFunction(name: "anneal", constantValues: constantValues) {(function, error) in
                            guard function != nil && error == nil else {
                                callback(false)
                                return
                            }

                            self.annealFunction = function

                            callback(true)
                        }
                    }
                }
            }
        } catch {
            callback(false)
        }
    }

    private func createMetalStates(callback: @escaping (Bool) -> Void) {
        let computePipelineDescriptor = MTLComputePipelineDescriptor()
        computePipelineDescriptor.computeFunction = fitnessFunction
        computePipelineDescriptor.buffers[0].mutability = .immutable
        computePipelineDescriptor.buffers[1].mutability = .immutable
        computePipelineDescriptor.buffers[2].mutability = .immutable
        computePipelineDescriptor.buffers[3].mutability = .mutable
        device.makeComputePipelineState(descriptor: computePipelineDescriptor, options: []) {(computePipelineState, reflection, error) in
            guard computePipelineState != nil && error == nil else {
                callback(false)
                return
            }

            self.fitnessState = computePipelineState

            let computePipelineDescriptor = MTLComputePipelineDescriptor()
            computePipelineDescriptor.computeFunction = self.sumFitnessesFunction
            computePipelineDescriptor.buffers[0].mutability = .immutable
            computePipelineDescriptor.buffers[1].mutability = .mutable
            self.device.makeComputePipelineState(descriptor: computePipelineDescriptor, options: []) {(computePipelineState, reflection, error) in
                guard computePipelineState != nil && error == nil else {
                    callback(false)
                    return
                }

                self.sumFitnessesState = computePipelineState

                let computePipelineDescriptor = MTLComputePipelineDescriptor()
                computePipelineDescriptor.computeFunction = self.swapGlyphsFunction
                computePipelineDescriptor.buffers[0].mutability = .mutable
                computePipelineDescriptor.buffers[1].mutability = .immutable
                self.device.makeComputePipelineState(descriptor: computePipelineDescriptor, options: []) {(computePipelineState, reflection, error) in
                    guard computePipelineState != nil && error == nil else {
                        callback(false)
                        return
                    }

                    self.swapGlyphsState = computePipelineState

                    let computePipelineDescriptor = MTLComputePipelineDescriptor()
                    computePipelineDescriptor.computeFunction = self.annealFunction
                    computePipelineDescriptor.buffers[0].mutability = .mutable
                    computePipelineDescriptor.buffers[1].mutability = .immutable
                    computePipelineDescriptor.buffers[2].mutability = .immutable
                    computePipelineDescriptor.buffers[3].mutability = .mutable
                    self.device.makeComputePipelineState(descriptor: computePipelineDescriptor, options: []) {(computePipelineState, reflection, error) in
                        guard computePipelineState != nil && error == nil else {
                            callback(false)
                            return
                        }

                        self.annealState = computePipelineState

                        callback(true)
                    }
                }
            }
        }
    }

    private func createBuffers() -> Bool {
        var seedsData = [UInt32]()
        for seed in seeds {
            seedsData.append(contentsOf: seed.map {UInt32($0)})
        }
        guard let generationBuffer = device.makeBuffer(bytes: &seedsData, length: MemoryLayout<UInt32>.stride * seedsData.count, options: .storageModeManaged) else {
            return false
        }
        self.generationBuffer = generationBuffer

        var glyphSizesData = glyphSizes.map {UInt32($0)}
        guard let glyphSizesBuffer = device.makeBuffer(bytes: &glyphSizesData, length: MemoryLayout<UInt32>.stride * glyphSizesData.count, options: .storageModeManaged) else {
            return false
        }
        self.glyphSizesBuffer = glyphSizesBuffer

        guard let urlBitmapsBuffer = createURLBitmapsBuffer(glyphCount: glyphCount, requiredGlyphs: requiredGlyphs, device: device) else {
            return false
        }
        self.urlBitmapsBuffer = urlBitmapsBuffer.buffer
        self.glyphBitfieldSize = urlBitmapsBuffer.glyphBitfieldSize

        guard let fitnessesPerURLBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.stride * generationSize * urlCount, options: .storageModePrivate) else {
            return false
        }
        self.fitnessesPerURLBuffer = fitnessesPerURLBuffer

        guard let fitnessABuffer = device.makeBuffer(length: MemoryLayout<Float32>.stride * generationSize, options: .storageModePrivate) else {
            return false
        }
        self.fitnessABuffer = fitnessABuffer

        guard let fitnessBBuffer = device.makeBuffer(length: MemoryLayout<Float32>.stride * generationSize, options: .storageModePrivate) else {
            return false
        }
        self.fitnessBBuffer = fitnessBBuffer

        guard let fitnessMonitorABuffer = device.makeBuffer(length: MemoryLayout<Float32>.stride * generationSize, options: .storageModeManaged) else {
            return false
        }
        self.fitnessMonitorABuffer = fitnessMonitorABuffer

        guard let fitnessMonitorBBuffer = device.makeBuffer(length: MemoryLayout<Float32>.stride * generationSize, options: .storageModeManaged) else {
            return false
        }
        self.fitnessMonitorBBuffer = fitnessMonitorBBuffer

        return true
    }

    private func computeInitialFitnesses(callback: @escaping (Bool) -> Void) {
        guard let commandBuffer = queue.makeCommandBuffer() else {
            callback(false)
            return
        }
        guard let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            callback(false)
            return
        }
        computeFitnesses(computeCommandEncoder: computeCommandEncoder, fitnessBuffer: fitnessABuffer)
        computeCommandEncoder.endEncoding()
        commandBuffer.addCompletedHandler {(commandBuffer) in
            callback(commandBuffer.error == nil)
        }
        commandBuffer.commit()
    }

    public func prepare() {
        state = true
        let operationQueue = OperationQueue()
        operationQueue.addOperation {
            guard self.createBuffers() else {
                self.delegate?.prepared(success: false)
                return
            }
            self.loadShaders {(result: Bool) in
                guard result else {
                    self.delegate?.prepared(success: false)
                    return
                }
                self.createMetalStates {(result: Bool) in
                    guard result else {
                        self.delegate?.prepared(success: false)
                        return
                    }
                    self.computeInitialFitnesses {(result: Bool) in
                        self.delegate?.prepared(success: result)
                    }
                }
            }
        }
    }

    private func computeFitnesses(computeCommandEncoder: MTLComputeCommandEncoder, fitnessBuffer: MTLBuffer) {
        computeCommandEncoder.setComputePipelineState(fitnessState)
        computeCommandEncoder.setBuffers([generationBuffer, glyphSizesBuffer, urlBitmapsBuffer, fitnessesPerURLBuffer], offsets: [0, 0, 0, 0], range: 0 ..< 4)
        computeCommandEncoder.dispatchThreads(MTLSize(width: generationSize, height: urlCount, depth: 1), threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1))

        computeCommandEncoder.setComputePipelineState(sumFitnessesState)
        computeCommandEncoder.setBuffers([fitnessesPerURLBuffer, fitnessBuffer], offsets: [0, 0], range: 0 ..< 2)
        computeCommandEncoder.dispatchThreads(MTLSize(width: generationSize, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 512, height: 1, depth: 1))
    }

    private func swapGlyphs(computeCommandEncoder: MTLComputeCommandEncoder, indices: [UInt32]) {
        computeCommandEncoder.setComputePipelineState(swapGlyphsState)
        computeCommandEncoder.setBuffer(generationBuffer, offset: 0, index: 0)
        computeCommandEncoder.setBytes(indices, length: MemoryLayout<UInt32>.stride * indices.count, index: 1)
        computeCommandEncoder.dispatchThreads(MTLSize(width: generationSize, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 512, height: 1, depth: 1))
    }

    private func anneal(computeCommandEncoder: MTLComputeCommandEncoder, indices: [UInt32], beforeFitnesses: MTLBuffer, afterFitnesses: MTLBuffer) {
        computeCommandEncoder.setComputePipelineState(annealState)
        computeCommandEncoder.setBuffer(generationBuffer, offset: 0, index: 0)
        computeCommandEncoder.setBytes(indices, length: MemoryLayout<UInt32>.stride * indices.count, index: 1)
        computeCommandEncoder.setBuffers([beforeFitnesses, afterFitnesses], offsets: [0, 0], range: 2 ..< 4)
        computeCommandEncoder.dispatchThreads(MTLSize(width: generationSize, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 512, height: 1, depth: 1))
    }

    private func iteration(callback: @escaping (Bool) -> Void) {
        guard fitnessABuffer != nil && fitnessBBuffer != nil else {
            callback(false)
            return
        }

        var indices = [UInt32]()
        for _ in 0 ..< generationSize * 2 {
            indices.append(UInt32(arc4random_uniform(UInt32(glyphCount))))
        }

        let beforeFitnesses = state ? fitnessABuffer! : fitnessBBuffer!
        let afterFitnesses = state ? fitnessBBuffer! : fitnessABuffer!

        guard let commandBuffer = queue.makeCommandBuffer(), let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            callback(false)
            return
        }
        swapGlyphs(computeCommandEncoder: computeCommandEncoder, indices: indices)
        computeFitnesses(computeCommandEncoder: computeCommandEncoder, fitnessBuffer: afterFitnesses)
        anneal(computeCommandEncoder: computeCommandEncoder, indices: indices, beforeFitnesses: beforeFitnesses, afterFitnesses: afterFitnesses)
        computeCommandEncoder.endEncoding()

        var shouldMonitor = false
        if !monitoring {
            shouldMonitor = true
            guard let blitCommandEncoder = commandBuffer.makeBlitCommandEncoder() else {
                callback(false)
                return
            }
            blitCommandEncoder.copy(from: afterFitnesses, sourceOffset: 0, to: fitnessMonitorABuffer, destinationOffset: 0, size: MemoryLayout<Float32>.stride * generationSize)
            blitCommandEncoder.synchronize(resource: fitnessMonitorABuffer)
            blitCommandEncoder.endEncoding()
            monitoring = true
        }

        commandBuffer.addCompletedHandler {(commandBuffer) in
            OperationQueue.main.addOperation {
                if shouldMonitor {
                    let pointer = self.fitnessMonitorABuffer.contents().bindMemory(to: Float32.self, capacity: self.generationSize)
                    var best = Float(0)
                    for i in 0 ..< self.generationSize {
                        best = max(best, Float(pointer[i]))
                    }
                    self.delegate?.report(fitness: best)
                    self.monitoring = false
                }

                callback(commandBuffer.error == nil)
            }
        }
        commandBuffer.commit()
        state = !state
        
        if iterationCount != nil {
            iterationIndex! += 1
            if iterationCount! == iterationIndex! {
                stopping = true
            }
        }
    }

    private func getBestOrder() {
        guard let commandBuffer = queue.makeCommandBuffer(), let blitCommandEncoder = commandBuffer.makeBlitCommandEncoder() else {
            delegate?.stopped(results: nil)
            return
        }

        blitCommandEncoder.synchronize(resource: generationBuffer)
        blitCommandEncoder.copy(from: fitnessABuffer, sourceOffset: 0, to: fitnessMonitorABuffer, destinationOffset: 0, size: generationSize)
        blitCommandEncoder.copy(from: fitnessBBuffer, sourceOffset: 0, to: fitnessMonitorBBuffer, destinationOffset: 0, size: generationSize)
        blitCommandEncoder.synchronize(resource: fitnessMonitorABuffer)
        blitCommandEncoder.synchronize(resource: fitnessMonitorBBuffer)
        blitCommandEncoder.endEncoding()
        commandBuffer.addCompletedHandler {(commandBuffer) in
            let fitnessPointerA = self.fitnessMonitorABuffer.contents().bindMemory(to: Float32.self, capacity: self.generationSize)
            let fitnessPointerB = self.fitnessMonitorBBuffer.contents().bindMemory(to: Float32.self, capacity: self.generationSize)
            var best = Float(0)
            var bestIndex = self.generationSize
            for i in 0 ..< self.generationSize {
                let fitness = Float(max(fitnessPointerA[i], fitnessPointerB[i]))
                if fitness > best {
                    best = fitness
                    bestIndex = i
                }
            }
            guard bestIndex < self.generationSize else {
                self.delegate?.stopped(results: nil)
                return
            }
            let generationPointer = self.generationBuffer.contents().bindMemory(to: UInt32.self, capacity: self.generationSize * self.glyphCount)
            var glyphOrder = [Int]()
            for i in self.glyphCount * bestIndex ..< self.glyphCount * (bestIndex + 1) {
                glyphOrder.append(Int(generationPointer[i]))
            }
            self.delegate?.stopped(results: OptimizerResults(glyphOrder: glyphOrder, finalFitness: best))
        }
        commandBuffer.commit()
    }

    private func callback(success: Bool) {
        if !success {
            stopping = true
        }
        guard !stopping else {
            stopCount += 1
            if stopCount == inFlight {
                stopping = false
                stopCount = 0
                getBestOrder()
            }
            return
        }
        iteration(callback: callback)
    }

    public func optimize() {
        if iterationCount != nil {
            iterationIndex = 0
        }
        for _ in 0 ..< inFlight {
            iteration(callback: callback)
        }
    }

    public func stop() {
        stopping = true
    }
}
