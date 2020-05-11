//
//  ChooseSeedsViewController.swift
//  FontOptimizer
//
//  Created by Myles C. Maxfield on 5/10/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

import Cocoa
import Optimizer

protocol ChooseSeedsViewControllerDelegate : class {
    var prunedGlyphSizes: GlyphSizes? { get }
    var prunedRequiredGlyphs: [Set<CGGlyph>]? { get }
    var chosenSeeds: [[Int]]! { get set }
    var device: MTLDevice? { get }
}

class ChooseSeedsViewController: NSViewController {
    @IBOutlet var frequencyOrderCheckbox: NSButton!
    @IBOutlet var lastBestCheckbox: NSButton!
    @IBOutlet var placedBestCheckbox: NSButton!
    @IBOutlet var allBestCheckbox: NSButton!
    @IBOutlet var goButton: NSButton!
    @IBOutlet var progressIndicator: NSProgressIndicator!
    weak var delegate: ChooseSeedsViewControllerDelegate!

    @IBAction func go(_ sender: NSButton) {
        guard let prunedGlyphSizes = delegate?.prunedGlyphSizes, let prunedRequiredGlyphs = delegate?.prunedRequiredGlyphs, let device = delegate?.device else {
            delegate = nil
            dismiss(nil)
            return
        }

        frequencyOrderCheckbox.isEnabled = false
        lastBestCheckbox.isEnabled = false
        placedBestCheckbox.isEnabled = false
        allBestCheckbox.isEnabled = false
        goButton.isEnabled = false
        progressIndicator.isHidden = false

        let doFrequencyOrder = frequencyOrderCheckbox.state == .on
        let doLastBestOrder = lastBestCheckbox.state == .on
        let doPlacedBest = placedBestCheckbox.state == .on
        let doAllBest = allBestCheckbox.state == .on

        var count = 0
        if doFrequencyOrder {
            count += 1
        }
        if doLastBestOrder {
            count += 1
        }
        if doPlacedBest {
            count += 1
        }
        if doAllBest {
            count += 1
        }
        progressIndicator.minValue = 0
        progressIndicator.maxValue = Double(count * prunedGlyphSizes.glyphSizes.count)
        progressIndicator.doubleValue = 0

        var seeds = [[Int]]()
        if doFrequencyOrder {
            seeds.append(frequencyOrder(glyphCount: prunedGlyphSizes.glyphSizes.count, requiredGlyphs: prunedRequiredGlyphs))
        }
        progressIndicator.doubleValue += Double(prunedGlyphSizes.glyphSizes.count)
        if doLastBestOrder || doPlacedBest || doAllBest {
            computeBigramScores(glyphCount: prunedGlyphSizes.glyphSizes.count, requiredGlyphs: prunedRequiredGlyphs, device: device) {(bigramScores) in
                let operationQueue = OperationQueue()
                operationQueue.addOperation {
                    if bigramScores != nil {
                        if doLastBestOrder {
                            if let lastBestOrder = lastBest(glyphCount: prunedGlyphSizes.glyphSizes.count, bigramScores: bigramScores!, progressCallback: {() in
                                OperationQueue.main.addOperation {
                                    self.progressIndicator.doubleValue += 1
                                }
                            }) {
                                seeds.append(lastBestOrder)
                            } else {
                                OperationQueue.main.addOperation {
                                    self.progressIndicator.doubleValue += Double(prunedGlyphSizes.glyphSizes.count)
                                }
                            }
                        }
                        if doPlacedBest {
                            if let placedBestOrder = placedBest(glyphCount: prunedGlyphSizes.glyphSizes.count, bigramScores: bigramScores!, progressCallback: {() in
                                OperationQueue.main.addOperation {
                                    self.progressIndicator.doubleValue += 1
                                }
                            }) {
                                seeds.append(placedBestOrder)
                            } else {
                                OperationQueue.main.addOperation {
                                    self.progressIndicator.doubleValue += Double(prunedGlyphSizes.glyphSizes.count)
                                }
                            }
                        }
                        if doAllBest {
                            // FIXME: Implement this
                        }
                    }
                    OperationQueue.main.addOperation {
                        self.delegate?.chosenSeeds = seeds
                        self.dismiss(nil)
                    }
                }
            }
        } else {
            self.delegate?.chosenSeeds = seeds
            self.dismiss(nil)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = (presentingViewController! as! ChooseSeedsViewControllerDelegate)
    }
}
