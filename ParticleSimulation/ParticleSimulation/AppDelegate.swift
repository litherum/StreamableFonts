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
    var mtkView: MTKView!
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

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        guard let mtkView = window.contentView as? MTKView else {
            fatalError()
        }
        self.mtkView = mtkView
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
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
    
    func draw(in view: MTKView) {
        guard mtkView != nil else {
            return
        }
        let commandBuffer = queue.makeCommandBuffer()!

        let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!
        computeCommandEncoder.setComputePipelineState(computePipelineState)
        computeCommandEncoder.setBuffers([particleBuffer, countBuffer, scoresBuffer], offsets: [0, 0, 0], range: 0 ..< 3)
        computeCommandEncoder.setBytes(&time, length: MemoryLayout<UInt32>.size, index: 3)
        computeCommandEncoder.dispatchThreads(MTLSize(width: particleCount, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
        computeCommandEncoder.endEncoding()

        let screenSize = [UInt32(mtkView.bounds.width), UInt32(mtkView.bounds.height)]
        let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: mtkView.currentRenderPassDescriptor!)!
        renderCommandEncoder.setRenderPipelineState(renderPipelineState)
        renderCommandEncoder.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(mtkView.bounds.width), height: Double(mtkView.bounds.height), znear: 0, zfar: 1))
        renderCommandEncoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)
        renderCommandEncoder.setFragmentBytes(screenSize, length: MemoryLayout<UInt32>.size * screenSize.count, index: 0)
        renderCommandEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleCount)
        renderCommandEncoder.endEncoding()

        commandBuffer.present(mtkView.currentDrawable!)
        commandBuffer.commit()

        time += 1
    }
}

