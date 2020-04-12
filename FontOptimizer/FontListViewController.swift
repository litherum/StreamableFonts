//
//  FontListViewController.swift
//  FontOptimizer
//
//  Created by Myles C. Maxfield on 4/9/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

import Cocoa
import Optimizer

class FontObject: NSObject {
    let fontDescriptor: CTFontDescriptor
    let glyphSizes: GlyphSizes
    @objc var postScriptName = ""
    @objc var path = ""
    @objc var size = 0
    @objc var glyphsSize = 0
    init(fontDescriptor: CTFontDescriptor, glyphSizes: GlyphSizes) {
        self.fontDescriptor = fontDescriptor
        self.glyphSizes = glyphSizes
        if let postScriptName = CTFontDescriptorCopyAttribute(fontDescriptor, kCTFontNameAttribute) {
            if let name = postScriptName as? String {
                self.postScriptName = name
            }
        }
        if let urlObject = CTFontDescriptorCopyAttribute(fontDescriptor, kCTFontURLAttribute) {
            if let url = urlObject as? URL {
                if url.isFileURL {
                    self.path = url.path
                }
            }
        }
        size = glyphSizes.fontSize
        glyphsSize = glyphSizes.glyphSizes.reduce(0, +)
    }
}

@objc protocol FontListViewControllerDelegate : class {
    var currentFont: CTFont? { get set }
    var glyphSizes: GlyphSizes? { get set }
}

class FontListViewController: NSViewController {
    @IBOutlet @objc dynamic var fontListArrayController: NSArrayController!
    @IBOutlet var spinner: NSProgressIndicator!
    @IBOutlet var container: NSView!
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

        spinner.startAnimation(nil)

        let operationQueue = OperationQueue()
        if let testFont = self.chineseSystemFont() {
            if let glyphSizes = computeGlyphSizes(font: testFont) {
                let fontObject = FontObject(fontDescriptor: CTFontCopyFontDescriptor(testFont), glyphSizes: glyphSizes)
                self.fontListArrayController.addObject(fontObject)
            }
        }
        if let systemFont = CTFontCreateUIFontForLanguage(.system, 0, nil) {
            let systemFontDescriptor = CTFontCopyFontDescriptor(systemFont)
            if let glyphSizes = computeGlyphSizes(font: CTFontCreateWithFontDescriptor(systemFontDescriptor, 0, nil)) {
                let systemFontObject = FontObject(fontDescriptor: systemFontDescriptor, glyphSizes: glyphSizes)
                OperationQueue.main.addOperation {
                    self.fontListArrayController.addObject(systemFontObject)
                }
            }
            if let cascadeList = CTFontCopyDefaultCascadeListForLanguages(systemFont, nil) as? [CTFontDescriptor] {
                for descriptor in cascadeList {
                    operationQueue.addOperation {
                        if let glyphSizes = computeGlyphSizes(font: CTFontCreateWithFontDescriptor(descriptor, 0, nil)) {
                            let fontObject = FontObject(fontDescriptor: descriptor, glyphSizes: glyphSizes)
                            OperationQueue.main.addOperation {
                                self.fontListArrayController.addObject(fontObject)
                            }
                        }
                    }
                }
            }
        }
        let emptyFontDescriptor = CTFontDescriptorCreateWithAttributes([:] as NSDictionary)
        if let allFontDescriptors = CTFontDescriptorCreateMatchingFontDescriptors(emptyFontDescriptor, nil) as? [CTFontDescriptor] {
            for fontDescriptor in allFontDescriptors {
                operationQueue.addOperation {
                    if let glyphSizes = computeGlyphSizes(font: CTFontCreateWithFontDescriptor(fontDescriptor, 0, nil)) {
                        let fontObject = FontObject(fontDescriptor: fontDescriptor, glyphSizes: glyphSizes)
                        OperationQueue.main.addOperation {
                            self.fontListArrayController.addObject(fontObject)
                        }
                    }
                }
            }
        }

        operationQueue.addBarrierBlock {
            OperationQueue.main.addOperation {
                self.spinner.stopAnimation(nil)
                self.spinner.isHidden = true
                self.container.isHidden = false
                self.fontListArrayController.setSelectionIndex(0)
                self.updateFont()
                self.observation = self.observe(\.fontListArrayController.selectionIndexes) {(keyValueCodingAndObserving, change) in
                    self.updateFont()
                }
            }
        }

    }

    @IBAction func addFont(_ sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = true
        openPanel.begin {(response) in
            guard response == .OK else {
                return
            }
            let fileManager = FileManager.default
            let operationQueue = OperationQueue()
            let addURL = {(url: URL) in
                guard let fontDescriptors = CTFontManagerCreateFontDescriptorsFromURL(url as NSURL) as? [CTFontDescriptor] else {
                    return
                }
                for fontDescriptor in fontDescriptors {
                    if let glyphSizes = computeGlyphSizes(font: CTFontCreateWithFontDescriptor(fontDescriptor, 0, nil)) {
                        OperationQueue.main.addOperation {
                            self.fontListArrayController.addObject(FontObject(fontDescriptor: fontDescriptor, glyphSizes: glyphSizes))
                        }
                    }
                }
            }
            for url in openPanel.urls {
                addURL(url)
                guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: nil) else {
                    continue
                }
                for object in enumerator {
                    operationQueue.addOperation {
                        guard let url = object as? URL else {
                            return
                        }
                        addURL(url)
                    }
                }
            }
        }
    }

    func updateFont() {
        guard let selectedObjects = fontListArrayController.selectedObjects else {
            return
        }
        guard !selectedObjects.isEmpty else {
            return
        }
        let fontObject = selectedObjects[0] as! FontObject
        delegate?.currentFont = CTFontCreateWithFontDescriptor(fontObject.fontDescriptor, 0, nil)
        delegate?.glyphSizes = fontObject.glyphSizes
    }
}
