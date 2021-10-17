# cython: language_level=3, cdivision=True

''' 
	This is the header file for the arrex cython-only API. 
	Of course you can use the python API to complete what is here.
'''

cimport cython
from cpython cimport PyObject

ctypedef int (*c_pack_t) (PyObject*, void*, PyObject*) except -1
ctypedef PyObject* (*c_unpack_t) (PyObject*, void*) except NULL

cdef class DType:
	''' base class for a dtype, But you should use on of its specialization instead '''
	cdef public size_t dsize
	cdef c_pack_t c_pack
	cdef c_unpack_t c_unpack
	cdef public bytes layout
	cdef public object key

	
cpdef declare(key, DType dtype)
cpdef DType declared(key)
