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
    var chosenSeeds: [[Int]]! { get set }
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
        frequencyOrderCheckbox.isEnabled = false
        lastBestCheckbox.isEnabled = false
        placedBestCheckbox.isEnabled = false
        allBestCheckbox.isEnabled = false
        goButton.isEnabled = false
        progressIndicator.isHidden = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = (presentingViewController! as! ChooseSeedsViewControllerDelegate)
    }
}
