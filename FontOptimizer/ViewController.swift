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

        if let activeDisplayID = view.window?.screen?.deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as? CGDirectDisplayID {
            if let activeDevice = CGDirectDisplayCopyCurrentMetalDevice(activeDisplayID) {
                for device in MTLCopyAllDevices() {
                    if activeDevice.name != device.name { // This isn't perfect, but I can't seem to get withUnsafePointer(to:) to work with these MTLDevices
                        self.device = device
                        break
                    }
                }
            }
        }
        if device == nil {
            device = MTLCreateSystemDefaultDevice()
        }

        fontListViewController = (children[0] as! FontListViewController)
        settingsViewController = (children[1] as! SettingsViewController)
        optimizerViewController = (children[2] as! OptimizerViewController)

        fontListViewController.delegate = self
        settingsViewController.delegate = self
        optimizerViewController.delegate = self

        fontListViewController.updateFont()
    }

    func setRoundTripTime(result: Double) {
        roundTripInBytes = result
    }

    private func prune() {
        guard let glyphSizes = self.glyphSizes, let requiredGlyphs = self.requiredGlyphs else {
            return
        }
        var set = Set<CGGlyph>()
        for glyphs in requiredGlyphs {
            set = set.union(glyphs)
        }

        glyphMapping = Array(repeating: CGGlyph(0), count: glyphSizes.glyphSizes.count)
        var newIndex = CGGlyph(1)
        for i in 1 ..< glyphSizes.glyphSizes.count {
            if set.contains(CGGlyph(i)) {
                glyphMapping![i] = newIndex
                newIndex += 1
            }
        }

        var newGlyphSizes = Array(repeating: 0, count: Int(newIndex))
        newGlyphSizes[0] = glyphSizes.glyphSizes[0]
        for i in 1 ..< glyphSizes.glyphSizes.count {
            if glyphMapping![i] != 0 {
                newGlyphSizes[Int(glyphMapping![i])] = glyphSizes.glyphSizes[i]
            }
        }
        prunedGlyphSizes = GlyphSizes(fontSize: glyphSizes.fontSize, glyphSizes: newGlyphSizes)

        prunedRequiredGlyphs = [Set<CGGlyph>]()
        for glyphs in requiredGlyphs {
            let newSet = Set<CGGlyph>(glyphs.map { glyphMapping![Int($0)] })
            prunedRequiredGlyphs!.append(newSet)
        }
    }

    func checkIfReady() {
        let seedCount = (chosenSeeds?.count ?? 0) + (randomSeeds?.count ?? 0)
        optimizerViewController.isReady = !optimizerViewController.isOptimizing && glyphSizes != nil && requiredGlyphs != nil && requiredGlyphs?.count != 0 && chosenSeeds != nil && seedCount > 0 && roundTripInBytes > 0
    }
}

