//
//  ViewController.swift
//  FontOptimizer
//
//  Created by Myles C. Maxfield on 4/8/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

import Cocoa
import Optimizer
import Metal

class ViewController: NSSplitViewController, FontListViewControllerDelegate, SettingsViewControllerDelegate, OptimizerViewControllerDelegate {
    var fontListViewController: FontListViewController!
    var settingsViewController: SettingsViewController!
    var optimizerViewController: OptimizerViewController!
    var currentFont: CTFont!
    var glyphSizes: GlyphSizes? {
        didSet {
            checkIfReady()
        }
    }
    var requiredGlyphs: [Set<CGGlyph>]? {
        didSet {
            checkIfReady()
        }
    }
    @objc dynamic var roundTripInBytes = Double(0) {
        didSet {
            checkIfReady()
        }
    }

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

    func setFont(font: CTFont) {
        self.currentFont = font
    }

    func setRoundTripTime(result: Double) {
        roundTripInBytes = result
    }

    func checkIfReady() {
        guard !optimizerViewController.isOptimizing && glyphSizes != nil && requiredGlyphs?.count != 0 else {
            return
        }
        optimizerViewController.isReady = true
    }
}

