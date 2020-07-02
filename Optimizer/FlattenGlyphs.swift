//
//  Flatten.swift
//  Optimizer
//
//  Created by Myles C. Maxfield on 7/1/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

import Foundation
import Python

public func flattenGlyphs(inputFilename: String, fontNumber: Optional<Int>, outputFilename: String) -> Bool {
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
    defer {
        Py_Finalize()
    }

    guard let pythonTestModule = PyImport_ImportModule("FlattenGlyphs") else {
        if PyErr_Occurred() != nil {
            PyErr_PrintEx(0)
        }
        return false
    }
    defer {
        Py_DecRef(pythonTestModule)
    }

    guard let function = PyObject_GetAttrString(pythonTestModule, "flattenGlyphs") else {
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

    guard let outputString = PyString_FromString(outputFilename) else {
        if PyErr_Occurred() != nil {
            PyErr_PrintEx(0)
        }
        return false
    }
    defer {
        Py_DecRef(outputString)
    }

    guard let arguments = PyTuple_Pack3(inputString, fontNumberObject, outputString) else {
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

    return true
}
