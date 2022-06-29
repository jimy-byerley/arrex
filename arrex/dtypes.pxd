# cython: language_level=3, cdivision=True

''' 
	This is the header file for the arrex cython-only API. 
	Of course you can use the python API to complete what is here.
'''

cimport cython
from cpython cimport PyObject

ctypedef int (*c_pack_t) (object, void*, object) except -1
ctypedef object (*c_unpack_t) (object, void*)

cdef class DDType:
	''' base class for a dtype, But you should use on of its specialization instead '''
	cdef public size_t dsize	# size of one element in a buffer
	cdef c_pack_t c_pack  		# pointer to the function that packs the python object into a buffer
	cdef c_unpack_t c_unpack 	# pointer to the function that create the python object using a buffer content
	cdef public bytes layout    # (optional)  element layout following specifications in module `struct`
	cdef public object key      # value to return when one asks an array for its dtype (it can be the current class itself, or any hashable value representing it)
	
	'''
	Just a piece of recommendation:
		
	- the method/function used to put in c_pack and c_unpack, MUST use type <object> as argument and return type, or it will wrongly increment/decrement its refcount and make a memory leak or a segfault
	'''

	
cpdef DDType declare(key, DDType dtype=*)
cpdef DDType declared(key)
