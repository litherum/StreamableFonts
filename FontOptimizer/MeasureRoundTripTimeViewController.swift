//
//  MeasureRoundTripTimeViewController.swift
//  FontOptimizer
//
//  Created by Myles C. Maxfield on 4/10/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

import Cocoa
import Optimizer

protocol MeasureRoundTripTimeViewControllerDelegate : class {
    var roundTripInBytes: Double { get set }
}

class MeasureRoundTripTimeViewController: NSViewController, RoundTripTimeMeasurerDelegate {
    @IBOutlet var iterationsTextField: NSTextField!
    @IBOutlet var urlTextField: NSTextField!
    @IBOutlet var progressIndicator: NSProgressIndicator!
    @IBOutlet var cancelButton: NSButton!
    @IBOutlet var measureButton: NSButton!
    var trials = 0
    var count = 0
    var samples = [Sample]()
    weak var delegate: MeasureRoundTripTimeViewControllerDelegate!

    func prepared(length: Int?) {
    }

    func producedSample(sample s: Sample?) {
        count += 1
        
        OperationQueue.main.addOperation {
            self.progressIndicator.doubleValue = (Double(self.count) / Double(self.trials))
        }

        if let sample = s {
            samples.append(sample)
        }
        if count == trials {
            OperationQueue.main.addOperation {
                if let result = RoundTripTimeMeasurer.calculateRoundTripOverheadInBytes(samples: self.samples) {
                    self.delegate?.roundTripInBytes = result
                    self.dismiss(nil)
                } else {
                    self.dismiss(nil)
                }
            }
        }
    }

    @IBAction func cancelButtonAction(_ sender: NSButton) {
        delegate = nil
        dismiss(nil)
    }

    @IBAction func measureButtonAction(_ sender: NSButton) {
        progressIndicator.isHidden = false
        measureButton.isEnabled = false
        if let url = URL(string: urlTextField.stringValue) {
            trials = iterationsTextField.integerValue
            let measurer = RoundTripTimeMeasurer(url: url, trials: trials, delegate: self)
            measurer.measure()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = (presentingViewController! as! MeasureRoundTripTimeViewControllerDelegate)
    }
}
