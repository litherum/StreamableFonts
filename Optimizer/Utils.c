//
//  Utils.c
//  Optimizer
//
//  Created by Myles C. Maxfield on 6/3/20.
//  Copyright © 2020 Myles C. Maxfield. All rights reserved.
//

#include "Utils.h"

PyObject* PyTuble_Pack4(PyObject* a, PyObject* b, PyObject* c, PyObject* d) {
    return PyTuple_Pack(4, a, b, c, d);
}
