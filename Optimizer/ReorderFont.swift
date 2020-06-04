//
//  ReorderFont.swift
//  Optimizer
//
//  Created by Myles C. Maxfield on 6/3/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

import Foundation
import Python

fileprivate func convertGlyphOrder(glyphOrder: [Int]) -> UnsafeMutablePointer<PyObject>! {
    guard let result = PyList_New(glyphOrder.count) else {
        return nil
    }

    for i in 0 ..< glyphOrder.count {
        let glyph = glyphOrder[i]

        guard let number = PyInt_FromLong(glyph) else {
            Py_DecRef(result)
            return nil
        }

        PyList_SetItem(result, i, number)

        Py_DecRef(number)
    }

    return result
}

public func reorderFont(inputFilename: String, fontNumber: Optional<Int>, glyphOrder: [Int], outputFilename: String) -> Bool {
    let scriptURL = Bundle(for: FontOptimizer.self).url(forResource: "ReorderFont", withExtension: "py")!
    let scriptContainerDirectory = scriptURL.deletingLastPathComponent()

    // FIXME: Is there a way to do this without modifying environment variables?
    if let existingPythonPath = getenv("PYTHONPATH") {
        let string = String(cString: existingPythonPath)
        setenv("PYTHONPATH", "\(scriptContainerDirectory.path):\(string)", 1)
    } else {
        setenv("PYTHONPATH", "\(scriptContainerDirectory.path)", 1)
    }

    Py_Initialize()
    guard let pythonTestModule = PyImport_ImportModule("ReorderFont") else {
        if PyErr_Occurred() != nil {
            PyErr_PrintEx(0)
        }
        return false
    }
    defer {
        Py_DecRef(pythonTestModule)
    }

    guard let function = PyObject_GetAttrString(pythonTestModule, "reorderFont") else {
        if PyErr_Occurred() != nil {
            PyErr_PrintEx(0)
        }
        return false
    }
    defer {
        Py_DecRef(function)
    }

    guard let inputString = PyString_FromString(inputFilename) else {
        if PyErr_Occurred() != nil {
            PyErr_PrintEx(0)
        }
        return false
    }
    defer {
        Py_DecRef(inputString)
    }

    guard let fontNumberObject = PyInt_FromLong(fontNumber ?? -1) else {
        if PyErr_Occurred() != nil {
            PyErr_PrintEx(0)
        }
        return false
    }
    defer {
        Py_DecRef(fontNumberObject)
    }

    guard let glyphOrderObject = convertGlyphOrder(glyphOrder: glyphOrder) else {
        if PyErr_Occurred() != nil {
            PyErr_PrintEx(0)
        }
        return false
    }
    defer {
        Py_DecRef(glyphOrderObject)
    }

    guard let outputString = PyString_FromString(outputFilename) else {
        if PyErr_Occurred() != nil {
            PyErr_PrintEx(0)
        }
        return false
    }
    defer {
        Py_DecRef(outputString)
    }

    guard let arguments = PyTuble_Pack4(inputString, fontNumberObject, glyphOrderObject, outputString) else {
        if PyErr_Occurred() != nil {
            PyErr_PrintEx(0)
        }
        return false
    }
    defer {
        Py_DecRef(arguments)
    }

    guard let result = PyObject_CallObject(function, arguments) else {
        if PyErr_Occurred() != nil {
            PyErr_PrintEx(0)
        }
        return false
    }
    defer {
        Py_DecRef(result)
    }

    if PyErr_Occurred() != nil {
        return false
    }
    
    let success = withUnsafePointer(to: &_Py_TrueStruct) {(pointer: UnsafePointer<PyIntObject>) in
        pointer.withMemoryRebound(to: PyObject.self, capacity: 1) {(pointer: UnsafePointer<PyObject>) in
            // FIXME: Is there a way to do this without treating an immutable pointer as mutable?
            return result == UnsafeMutablePointer(mutating: pointer)
        }
    }

    return success
}
