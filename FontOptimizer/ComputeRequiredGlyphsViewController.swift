//
//  ComputeRequiredGlyphsViewController.swift
//  FontOptimizer
//
//  Created by Myles C. Maxfield on 4/10/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

import Cocoa
import Optimizer

protocol ComputeRequiredGlyphsViewControllerDelegate : class {
    var currentFont: CTFont! { get }
    var requiredGlyphs: [Set<CGGlyph>]! { get set }
}

class ComputeRequiredGlyphsViewController: NSViewController {
    var url: URL!
    var urlContents = [String]()
    @IBOutlet var spinner: NSProgressIndicator!
    @IBOutlet var topStackView: NSStackView!
    @IBOutlet var urlCountLabel: NSTextField!
    @IBOutlet var sampleCountTextField: NSTextField!
    @IBOutlet var sampleCountSlider: NSSlider!
    @IBOutlet var progressIndicator: NSProgressIndicator!
    @IBOutlet var cancelButton: NSButton!
    @IBOutlet var computeButton: NSButton!
    @objc dynamic var sampleCount = 0 {
        didSet {
            sampleCountTextField.integerValue = sampleCount
            sampleCountSlider.integerValue = sampleCount
        }
    }
    weak var delegate: ComputeRequiredGlyphsViewControllerDelegate?
    
    @IBAction func cancelAction(_ sender: NSButton) {
        delegate = nil
        dismiss(nil)
    }

    @IBAction func computeAction(_ sender: NSButton) {
        var urlContentsCopy = urlContents
        var randomSample = [String]()
        for _ in 0 ..< sampleCount {
            let index = Int(arc4random_uniform(UInt32(urlContentsCopy.count)))
            randomSample.append(urlContentsCopy[index])
            urlContentsCopy.remove(at: index)
        }
        progressIndicator.isHidden = false
        computeButton.isEnabled = false
        sampleCountTextField.isEnabled = false
        sampleCountSlider.isEnabled = false

        var count = 0
        var requiredGlyphs = Array(repeating: Set<CGGlyph>(), count: sampleCount)
        guard let font = delegate?.currentFont else {
            return
        }
        let _ = Optimizer.computeRequiredGlyphs(font: font, urlContents: randomSample) {(index, set) in
            OperationQueue.main.addOperation {
                count += 1
                if let glyphs = set {
                    requiredGlyphs[index] = glyphs
                }
                self.progressIndicator.doubleValue = Double(count) / Double(self.sampleCount)
                if (count == self.sampleCount) {
                    self.delegate?.requiredGlyphs = requiredGlyphs
                    self.dismiss(nil)
                }
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = (presentingViewController as! ComputeRequiredGlyphsViewControllerDelegate)

        spinner.startAnimation(nil)
        let url = self.url!
        let operationQueue = OperationQueue()
        operationQueue.addOperation {
            do {
                // FIXME: IF this fails, do something other than spin forever
                let data = try Data(contentsOf: url)
                guard let jsonData = try! JSONSerialization.jsonObject(with: data) as? [Any] else {
                    return
                }
                for i in jsonData {
                    guard let item = i as? NSDictionary else {
                        return
                    }
                    guard let c = item.value(forKey: "Contents") else {
                        return
                    }
                    guard let contents = c as? String else {
                        return
                    }
                    self.urlContents.append(contents)
                }
                OperationQueue.main.addOperation {
                    self.spinner.stopAnimation(nil)
                    self.spinner.isHidden = true
                    self.topStackView.isHidden = false
                    self.urlCountLabel.stringValue = "\(self.urlContents.count) URLs"
                    self.sampleCountSlider.maxValue = Double(self.urlContents.count)
                    self.sampleCountSlider.integerValue = self.urlContents.count
                    self.sampleCountTextField.integerValue = self.urlContents.count
                    self.sampleCount = self.urlContents.count
                }
            } catch {
            }
        }
    }
}
