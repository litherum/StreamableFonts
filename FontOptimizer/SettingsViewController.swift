//
//  SettingsViewController.swift
//  FontOptimizer
//
//  Created by Myles C. Maxfield on 4/10/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

import Cocoa
import Optimizer

@objc protocol SettingsViewControllerDelegate : class {
    var currentFont: CTFont! { get }
    var requiredGlyphs: [Set<CGGlyph>]? { get set }
    var roundTripInBytes: Double { get set }
}

class SettingsViewController: NSViewController, ComputeRequiredGlyphsViewControllerDelegate, MeasureRoundTripTimeViewControllerDelegate {
    @IBOutlet var glyphSizesStatus: NSTextField!
    @IBOutlet var glyphSizesStatusWidthConstraint: NSLayoutConstraint!
    @IBOutlet var corpusExample: NSTextField!
    @IBOutlet var corpusExamleWidthConstraint: NSLayoutConstraint!
    @IBOutlet var corpusStatus: NSTextField!
    @IBOutlet var roundTripTimeTextField: NSTextField!
    var currentFont: CTFont! {
        get {
            return delegate?.currentFont
        }
    }
    var requiredGlyphs: [Set<CGGlyph>]! {
        get {
            return delegate?.requiredGlyphs
        }
        set {
            corpusStatus.isHidden = false
            corpusStatus.stringValue = "\(newValue.count) URLs"
            delegate?.requiredGlyphs = newValue
        }
    }
    var roundTripInBytes: Double {
        get {
            guard delegate != nil else {
                return 0
            }
            return delegate!.roundTripInBytes
        }
        set {
            roundTripTimeTextField.doubleValue = newValue
            delegate?.roundTripInBytes = newValue
        }
    }
    @objc weak var delegate: SettingsViewControllerDelegate!

    override func viewDidLoad() {
        super.viewDidLoad()

        if let fontDescriptor = NSFont.systemFont(ofSize: 0).fontDescriptor.withDesign(.monospaced) {
            let font = NSFont(descriptor: fontDescriptor, size: 0)
            corpusExample.font = font
            glyphSizesStatus.font = font
        }
        corpusExamleWidthConstraint.constant = corpusExample.intrinsicContentSize.width
    }

    func update(glyphSizes: GlyphSizes) {
        self.delegate?.requiredGlyphs = nil
        self.glyphSizesStatus.isHidden = false
        let total = glyphSizes.glyphSizes.reduce(0, +)
        let average = Double(total) / Double(glyphSizes.glyphSizes.count)
        let sorted = glyphSizes.glyphSizes.sorted()
        let median = sorted[sorted.count / 2]
        let byteCountFormatter = ByteCountFormatter()
        let numberFormatter = NumberFormatter()
        numberFormatter.minimumFractionDigits = 1
        numberFormatter.maximumFractionDigits = 1
        guard let percentage = numberFormatter.string(from: 100 * Double(total) / Double(glyphSizes.fontSize) as NSNumber) else {
            return
        }
        self.glyphSizesStatus.stringValue = """
Size: \(byteCountFormatter.string(fromByteCount: Int64(glyphSizes.fontSize)))
\(glyphSizes.glyphSizes.count) glyphs
\(percentage)% of the file is glyphs
Average glyph is \(byteCountFormatter.string(fromByteCount: Int64(average)))
Median glyph is \(byteCountFormatter.string(fromByteCount: Int64(median)))
"""
        self.glyphSizesStatusWidthConstraint.constant = self.glyphSizesStatus.intrinsicContentSize.width
    }

    @IBAction func selectCorpusFile(_ sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.begin {(response) in
            guard response == .OK else {
                return
            }
            guard let url = openPanel.url else {
                return
            }
            let storyboard = NSStoryboard(name: "Main", bundle: Bundle(for: SettingsViewController.self))
            let creator: ((NSCoder) -> ComputeRequiredGlyphsViewController?)? = nil
            let viewController = storyboard.instantiateController(identifier: "ComputeRequiredGlyphsViewControllerScene", creator: creator)
            viewController.url = url
            self.presentAsSheet(viewController)
        }
    }

    func setThreshold(threshold: Double) {
        roundTripTimeTextField.doubleValue = threshold
    }
}
