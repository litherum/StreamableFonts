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
    var requiredGlyphs: [Set<CGGlyph>]? { get }
    var roundTripInBytes: Double { get }
}

class OptimizerViewController: NSViewController, FontOptimizerDelegate {
    @IBOutlet var percentageTextField: NSTextField!
    @IBOutlet var progressIndicator: NSProgressIndicator!
    @IBOutlet var statusLabel: NSTextField!
    @IBOutlet var stopButton: NSButton!
    @IBOutlet var startButton: NSButton!
    var isOptimizing = false
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
        guard let device = MTLCreateSystemDefaultDevice() else {
            return
        }
        guard let glyphSizes = delegate?.glyphSizes else {
            return
        }
        guard let requiredGlyphs = delegate?.requiredGlyphs else {
            return
        }
        guard let roundTripInBytes = delegate?.roundTripInBytes else {
            return
        }

        isOptimizing = true
        // FIXME: Seeds
        var seed = [Int]()
        var totalGlyphSize = 0
        for i in 0 ..< glyphSizes.glyphSizes.count {
            seed.append(i)
            totalGlyphSize += glyphSizes.glyphSizes[i]
        }

        guard let fontOptimizer = FontOptimizer(glyphSizes: glyphSizes.glyphSizes, requiredGlyphs: requiredGlyphs, seeds: [seed], threshold: Int(roundTripInBytes), unconditionalDownloadSize: glyphSizes.fontSize - totalGlyphSize, fontSize: glyphSizes.fontSize, device: device, delegate: self) else {
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
    }

    func prepared(success: Bool) {
        OperationQueue.main.addOperation {
            self.startedOptimizing()
            self.fontOptimizer?.optimize()
        }
    }

    func report(fitness: Float) {
        OperationQueue.main.addOperation {
            guard let s = self.numberFormatter.string(from: fitness as NSNumber) else {
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

        numberFormatter.minimumFractionDigits = 1
        numberFormatter.maximumFractionDigits = 1
        
        if let fontDescriptor = NSFont.systemFont(ofSize: 70).fontDescriptor.withDesign(.monospaced) {
            let font = NSFont(descriptor: fontDescriptor, size: 70)
            percentageTextField.font = font
        }
    }
}