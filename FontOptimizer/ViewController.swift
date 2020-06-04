//
//  ViewController.swift
//  FontOptimizer
//
//  Created by Myles C. Maxfield on 4/8/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

import Cocoa
import Metal
import Optimizer

class ViewController: NSSplitViewController, FontListViewControllerDelegate, SettingsViewControllerDelegate, OptimizerViewControllerDelegate {
    var fontListViewController: FontListViewController!
    var settingsViewController: SettingsViewController!
    var optimizerViewController: OptimizerViewController!
    var currentFont: CTFont? {
        didSet {
            settingsViewController.requiredGlyphs = nil
            checkIfReady()
        }
    }
    var glyphSizes: GlyphSizes? {
        didSet {
            if let sizes = glyphSizes {
                settingsViewController.update(glyphSizes: sizes)
            }
            prune()
            checkIfReady()
        }
    }
    var prunedGlyphSizes: GlyphSizes?
    var requiredGlyphs: [Set<CGGlyph>]? {
        didSet {
            prune()
            checkIfReady()
        }
    }
    var prunedRequiredGlyphs: [Set<CGGlyph>]?
    var glyphMapping: [CGGlyph]? // glyphMapping[nonPrunedGlyph] = prunedGlyph
    var chosenSeeds: [[Int]]!
    var randomSeeds: [[Int]]!
    @objc dynamic var roundTripInBytes = Double(0) {
        didSet {
            checkIfReady()
        }
    }

    var isOptimizing = false {
        didSet {
            fontListViewController.disabled = isOptimizing
            settingsViewController.disabled = isOptimizing
        }
    }

    var device: MTLDevice?

    override func viewDidLoad() {
        super.viewDidLoad()

        fontListViewController = (children[0] as! FontListViewController)
        settingsViewController = (children[1] as! SettingsViewController)
        optimizerViewController = (children[2] as! OptimizerViewController)

        fontListViewController.delegate = self
        settingsViewController.delegate = self
        optimizerViewController.delegate = self

        fontListViewController.updateFont()
    }

    override func viewDidAppear() {
        if let activeDisplayID = view.window?.screen?.deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as? CGDirectDisplayID {
            if let activeDevice = CGDirectDisplayCopyCurrentMetalDevice(activeDisplayID) {
                for device in MTLCopyAllDevices() {
                    if activeDevice !== device {
                        self.device = device
                        break
                    }
                }
            }
        }
        if device == nil {
            device = MTLCreateSystemDefaultDevice()
        }
    }

    func setRoundTripTime(result: Double) {
        roundTripInBytes = result
    }

    private func prune() {
        guard let glyphSizes = self.glyphSizes, let requiredGlyphs = self.requiredGlyphs else {
            return
        }
        let prunedGlyphs = Optimizer.pruneGlyphs(glyphSizes: glyphSizes, requiredGlyphs: requiredGlyphs)
        glyphMapping = prunedGlyphs.glyphMapping
        prunedGlyphSizes = prunedGlyphs.glyphSizes
        prunedRequiredGlyphs = prunedGlyphs.requiredGlyphs
    }

    func checkIfReady() {
        let seedCount = (chosenSeeds?.count ?? 0) + (randomSeeds?.count ?? 0)
        optimizerViewController.isReady = !optimizerViewController.isOptimizing && glyphSizes != nil && requiredGlyphs != nil && requiredGlyphs?.count != 0 && chosenSeeds != nil && seedCount > 0 && roundTripInBytes > 0
    }
}

