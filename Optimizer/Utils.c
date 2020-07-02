//
//  Utils.c
//  Optimizer
//
//  Created by Myles C. Maxfield on 6/3/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

#include "Utils.h"

PyObject* PyTuple_Pack3(PyObject* a, PyObject* b, PyObject* c) {
    return PyTuple_Pack(3, a, b, c);
}

PyObject* PyTuple_Pack4(PyObject* a, PyObject* b, PyObject* c, PyObject* d) {
    return PyTuple_Pack(4, a, b, c, d);
}
