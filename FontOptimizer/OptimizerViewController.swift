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
    var chosenSeeds: [[Int]]! { get }
    var randomSeeds: [[Int]]! { get }
    var roundTripInBytes: Double { get }
    var isOptimizing: Bool { get set }
    var device: MTLDevice? { get }
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
        guard let device = delegate?.device,
            let glyphSizes = delegate?.glyphSizes,
            let prunedGlyphSizes = delegate?.prunedGlyphSizes,
            let prunedRequiredGlyphs = delegate?.prunedRequiredGlyphs,
            let chosenSeeds = delegate?.chosenSeeds,
            let randomSeeds = delegate?.randomSeeds,
            let roundTripInBytes = delegate?.roundTripInBytes else {
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

        
        guard let fontOptimizer = FontOptimizer(glyphSizes: prunedGlyphSizes.glyphSizes, requiredGlyphs: prunedRequiredGlyphs, seeds: chosenSeeds + randomSeeds, threshold: Int(roundTripInBytes), unconditionalDownloadSize: unconditionalDownloadSize, fontSize: glyphSizes.fontSize, device: device, delegate: self) else {
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
