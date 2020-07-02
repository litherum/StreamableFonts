//
//  Utils.h
//  Optimizer
//
//  Created by Myles C. Maxfield on 6/3/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

#pragma once

#include <Python/Python.h>

PyObject* PyTuple_Pack3(PyObject* a, PyObject* b, PyObject* c);
PyObject* PyTuple_Pack4(PyObject* a, PyObject* b, PyObject* c, PyObject* d);
