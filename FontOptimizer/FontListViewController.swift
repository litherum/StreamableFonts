//
//  FontListViewController.swift
//  FontOptimizer
//
//  Created by Myles C. Maxfield on 4/9/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

import Cocoa

class FontObject: NSObject {
    let fontDescriptor: CTFontDescriptor
    @objc var postScriptName: String {
        get {
            guard let postScriptName = CTFontDescriptorCopyAttribute(fontDescriptor, kCTFontNameAttribute) else {
                return ""
            }
            guard let name = postScriptName as? String else {
                return ""
            }
            return name
        }
    }
    @objc var path: String {
        get {
            guard let urlObject = CTFontDescriptorCopyAttribute(fontDescriptor, kCTFontURLAttribute) else {
                return ""
            }
            guard let url = urlObject as? URL else {
                return ""
            }
            guard url.isFileURL else {
                return ""
            }
            return url.path
        }
    }
    init(fontDescriptor: CTFontDescriptor) {
        self.fontDescriptor = fontDescriptor
    }
}

@objc protocol FontListViewControllerDelegate : class {
    var currentFont: CTFont! { get set }
}

class FontListViewController: NSViewController {
    @IBOutlet @objc dynamic var fontListArrayController: NSArrayController!
    weak var delegate: FontListViewControllerDelegate!
    var observation: NSKeyValueObservation?

    private func chineseSystemFont() -> CTFont? {
        guard let font = CTFontCreateUIFontForLanguage(.system, 0, "zh-Hans" as NSString) else {
            return nil
        }
        let attributedString = NSAttributedString(string: "國", attributes: [kCTFontAttributeName as NSAttributedString.Key : font])
        let line = CTLineCreateWithAttributedString(attributedString)
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else {
            return nil
        }
        guard runs.count == 1 else {
            return nil
        }
        let run = runs[0]
        let attributes = CTRunGetAttributes(run) as NSDictionary
        guard let usedFontObject = attributes[kCTFontAttributeName] else {
            return nil
        }
        let usedFont = usedFontObject as! CTFont
        return usedFont
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if let testFont = chineseSystemFont() {
            fontListArrayController.addObject(FontObject(fontDescriptor: CTFontCopyFontDescriptor(testFont)))
        }
        if let systemFont = CTFontCreateUIFontForLanguage(.system, 0, nil) {
            let systemFontDescriptor = CTFontCopyFontDescriptor(systemFont)
            fontListArrayController.addObject(FontObject(fontDescriptor: systemFontDescriptor))
            if let cascadeList = CTFontCopyDefaultCascadeListForLanguages(systemFont, nil) as? [CTFontDescriptor] {
                for descriptor in cascadeList {
                    fontListArrayController.addObject(FontObject(fontDescriptor: descriptor))
                }
            }
        }
        let emptyFontDescriptor = CTFontDescriptorCreateWithAttributes([:] as NSDictionary)
        if let allFontDescriptors = CTFontDescriptorCreateMatchingFontDescriptors(emptyFontDescriptor, nil) as? [CTFontDescriptor] {
            for fontDescriptor in allFontDescriptors {
                fontListArrayController.addObject(FontObject(fontDescriptor: fontDescriptor))
            }
        }
        fontListArrayController.setSelectionIndex(0)
        updateFont()

        observation = observe(\.fontListArrayController.selectionIndexes) {(keyValueCodingAndObserving, change) in
            self.updateFont()
        }
    }

    func updateFont() {
        delegate?.currentFont = CTFontCreateWithFontDescriptor((fontListArrayController.selectedObjects[0] as! FontObject).fontDescriptor, 0, nil)
    }
}
