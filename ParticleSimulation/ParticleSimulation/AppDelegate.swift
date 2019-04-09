//
//  AppDelegate.swift
//  ParticleSimulation
//
//  Created by Myles C. Maxfield on 4/4/19.
//  Copyright © 2019 Myles C. Maxfield. All rights reserved.
//

import Cocoa
import MetalKit
import Metal

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, MTKViewDelegate {
    @IBOutlet var window: NSWindow!
    @IBOutlet var mtkView: MTKView!
    var device: MTLDevice!
    var queue: MTLCommandQueue!
    var particleBuffer: MTLBuffer!
    var countBuffer: MTLBuffer!
    var timeBuffer: MTLBuffer!
    var scoresBuffer: MTLBuffer!
    var renderPipelineState: MTLRenderPipelineState!
    var computePipelineState: MTLComputePipelineState!
    var particleCount = 0
    var time = UInt32(0)
    var shouldWriteData = false
    var ready = false

    @IBAction func writeData(_ sender: NSButton) {
        shouldWriteData = true
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        mtkView.delegate = self
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        device = MTLCreateSystemDefaultDevice()!
        mtkView.device = device
        queue = device.makeCommandQueue()

        let program = device.makeDefaultLibrary()!
        let vertexFunction = program.makeFunction(name: "vertexShader")!
        let fragmentFunction = program.makeFunction(name: "fragmentShader")!
        let computeFunction = program.makeFunction(name: "computeShader")

        particleCount = 2216
        var particles = [float4]()
        for _ in 0 ..< particleCount {
            particles.append(float4(x: Float.random(in: -0.9 ..< 0.9), y: Float.random(in: -0.9 ..< 0.9), z: Float.random(in: -0.9 ..< 0.9), w: 1))
            particles.append(float4(x: Float.random(in: -1 ..< 1), y: Float.random(in: -1 ..< 1), z: Float.random(in: -1 ..< 1), w: 0) / 10)
        }
        particleBuffer = device.makeBuffer(bytes: particles, length: MemoryLayout<float4>.size * 2 * particleCount, options: .storageModeManaged)

        let countData = [UInt32(particleCount)]
        countBuffer = device.makeBuffer(bytes: countData, length: MemoryLayout<UInt32>.size, options: .storageModeManaged)

        timeBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.size, options: .storageModeManaged)

        let url = Bundle.main.url(forResource: "ChineseWebsiteFloatScores", withExtension: "data")!
        let floatScoresData = try! Data(contentsOf: url)
        assert(floatScoresData.count == MemoryLayout<Float>.size * particleCount * particleCount)
        floatScoresData.withUnsafeBytes {(body: UnsafeRawBufferPointer) in
            scoresBuffer = device.makeBuffer(bytes: body.baseAddress!, length: floatScoresData.count, options: .storageModeManaged)
        }

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float4
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<float4>.size * 2

        let colorAttachmentDescriptor = MTLRenderPipelineColorAttachmentDescriptor()
        colorAttachmentDescriptor.pixelFormat = mtkView.colorPixelFormat
        colorAttachmentDescriptor.isBlendingEnabled = true
        colorAttachmentDescriptor.sourceAlphaBlendFactor = .sourceAlpha
        colorAttachmentDescriptor.sourceRGBBlendFactor = .sourceAlpha
        colorAttachmentDescriptor.destinationAlphaBlendFactor = .one
        colorAttachmentDescriptor.destinationRGBBlendFactor = .one

        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
        renderPipelineDescriptor.colorAttachments[0] = colorAttachmentDescriptor
        renderPipelineDescriptor.inputPrimitiveTopology = .point
        renderPipelineState = try! device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)

        let computePipelineDescriptor = MTLComputePipelineDescriptor()
        computePipelineDescriptor.computeFunction = computeFunction
        computePipelineState = try! device.makeComputePipelineState(descriptor: computePipelineDescriptor, options: MTLPipelineOption(), reflection: nil)

        ready = true
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
    
    func draw(in view: MTKView) {
        guard ready == true else {
            return
        }

        let commandBuffer = queue.makeCommandBuffer()!

        let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!
        computeCommandEncoder.setComputePipelineState(computePipelineState)
        computeCommandEncoder.setBuffers([particleBuffer, countBuffer, scoresBuffer], offsets: [0, 0, 0], range: 0 ..< 3)
        computeCommandEncoder.setBytes(&time, length: MemoryLayout<UInt32>.size, index: 3)
        computeCommandEncoder.dispatchThreads(MTLSize(width: particleCount, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
        computeCommandEncoder.endEncoding()

        if shouldWriteData {
            let blitCommandEncoder = commandBuffer.makeBlitCommandEncoder()!
            blitCommandEncoder.synchronize(resource: particleBuffer)
            blitCommandEncoder.endEncoding()
        }

        let screenSize = [UInt32(window.screen!.convertRectToBacking(mtkView.bounds).width), UInt32(window.screen!.convertRectToBacking(mtkView.bounds).height)]
        let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: mtkView.currentRenderPassDescriptor!)!
        renderCommandEncoder.setRenderPipelineState(renderPipelineState)
        renderCommandEncoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)
        renderCommandEncoder.setFragmentBytes(screenSize, length: MemoryLayout<UInt32>.size * screenSize.count, index: 0)
        renderCommandEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleCount)
        renderCommandEncoder.endEncoding()

        commandBuffer.present(mtkView.currentDrawable!)

        if shouldWriteData {
            shouldWriteData = false
            ready = false
            commandBuffer.addCompletedHandler {(commandBuffer) in
                let memory = self.particleBuffer.contents().bindMemory(to: float4.self, capacity: self.particleCount * 2)
                var particles = [float4]()
                for i in 0 ..< self.particleCount {
                    particles.append(memory[i * 2])
                    particles.append(memory[i * 2 + 1])
                }
                let data = Data(bytes: &particles, count: MemoryLayout<float4>.size * self.particleCount * 2)
                let url = URL(fileURLWithPath: NSTemporaryDirectory() + "/positions.data")
                try! data.write(to: url)
                print("\(url.absoluteString)")
                self.ready = true
            }
        }

        commandBuffer.commit()

        time += 1
    }
}

