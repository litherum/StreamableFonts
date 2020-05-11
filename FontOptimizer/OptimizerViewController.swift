//
//  OptimizerViewController.swift
//  FontOptimizer
//
//  Created by Myles C. Maxfield on 4/10/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

import Cocoa
import Optimizer

protocol OptimizerViewControllerDelegate : class {
    var glyphSizes: GlyphSizes? { get }
    var prunedGlyphSizes: GlyphSizes? { get }
    var prunedRequiredGlyphs: [Set<CGGlyph>]? { get }
    var roundTripInBytes: Double { get }
    var isOptimizing: Bool { get set }
}

class OptimizerViewController: NSViewController, FontOptimizerDelegate {
    @IBOutlet var percentageTextField: NSTextField!
    @IBOutlet var progressIndicator: NSProgressIndicator!
    @IBOutlet var statusLabel: NSTextField!
    @IBOutlet var stopButton: NSButton!
    @IBOutlet var startButton: NSButton!
    var isOptimizing: Bool {
        get {
            return delegate?.isOptimizing ?? false
        }
        set {
            delegate?.isOptimizing = newValue
        }
    }
    var isReady = false {
        didSet {
            startButton.isEnabled = isReady
        }
    }
    var numberFormatter = NumberFormatter()
    var fontOptimizer: FontOptimizer?
    weak var delegate: OptimizerViewControllerDelegate?

    @IBAction func stopButtonAction(_ sender: NSButton) {
        fontOptimizer?.stop()
        stoppedOptimizing()
    }

    @IBAction func startButtonAction(_ sender: NSButton) {
        var testDevice: MTLDevice?
        if let activeDisplayID = view.window?.screen?.deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as? CGDirectDisplayID {
            if let activeDevice = CGDirectDisplayCopyCurrentMetalDevice(activeDisplayID) {
                for device in MTLCopyAllDevices() {
                    if activeDevice.name != device.name { // This isn't perfect, but I can't seem to get withUnsafePointer(to:) to work with these MTLDevices
                        testDevice = device
                        break
                    }
                }
            }
        }
        if testDevice == nil {
            testDevice = MTLCreateSystemDefaultDevice()
        }
        guard let device = testDevice else {
            return
        }
        guard let glyphSizes = delegate?.glyphSizes else {
            return
        }
        guard let prunedGlyphSizes = delegate?.prunedGlyphSizes else {
            return
        }
        guard let prunedRequiredGlyphs = delegate?.prunedRequiredGlyphs else {
            return
        }
        guard let roundTripInBytes = delegate?.roundTripInBytes else {
            return
        }

        isOptimizing = true
        // FIXME: Seeds
        var seed = [Int]()
        for i in 0 ..< prunedGlyphSizes.glyphSizes.count {
            seed.append(i)
        }

        var totalGlyphSize = 0
        for i in 0 ..< glyphSizes.glyphSizes.count {
            totalGlyphSize += glyphSizes.glyphSizes[i]
        }
        let unconditionalDownloadSize = glyphSizes.fontSize - totalGlyphSize

        guard let fontOptimizer = FontOptimizer(glyphSizes: prunedGlyphSizes.glyphSizes, requiredGlyphs: prunedRequiredGlyphs, seeds: [seed], threshold: Int(roundTripInBytes), unconditionalDownloadSize: unconditionalDownloadSize, fontSize: glyphSizes.fontSize, device: device, delegate: self) else {
            return
        }
        self.fontOptimizer = fontOptimizer
        fontOptimizer.prepare()
        startedPreparing()
    }

    func startedPreparing() {
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
        statusLabel.isHidden = false
        statusLabel.stringValue = "Preparing..."
        startButton.isEnabled = false
        stopButton.isEnabled = true
    }

    func startedOptimizing() {
        statusLabel.stringValue = "Optimizing..."
    }

    func stoppedOptimizing() {
        statusLabel.stringValue = "Stopping..."
        stopButton.isEnabled = false
    }

    func finishedOptimizing() {
        progressIndicator.stopAnimation(nil)
        progressIndicator.isHidden = true
        statusLabel.stringValue = "Stopped."
        stopButton.isEnabled = false
        startButton.isEnabled = isReady
        isOptimizing = false
    }

    func prepared(success: Bool) {
        OperationQueue.main.addOperation {
            self.startedOptimizing()
            self.fontOptimizer?.optimize()
        }
    }

    func report(fitness: Float) {
        OperationQueue.main.addOperation {
            guard let s = self.numberFormatter.string(from: fitness * 100 as NSNumber) else {
                return
            }
            self.percentageTextField.stringValue = "\(s)%"
        }
    }

    func stopped() {
        OperationQueue.main.addOperation {
            self.finishedOptimizing()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        numberFormatter.minimumFractionDigits = 5
        numberFormatter.maximumFractionDigits = 5
        
        if let fontDescriptor = NSFont.systemFont(ofSize: 70).fontDescriptor.withDesign(.monospaced) {
            let font = NSFont(descriptor: fontDescriptor, size: 70)
            percentageTextField.font = font
        }
    }
}
