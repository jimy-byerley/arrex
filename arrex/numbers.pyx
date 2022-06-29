# cython: language_level=3, cdivision=True

cimport cython
from cpython cimport PyObject, Py_DECREF
from libc.stdint cimport *
from .dtypes cimport *

cdef DDType decl


### declare double

cdef int pack_d(object dtype, double* place, object obj) except -1:
	place[0] = obj
cdef object unpack_d(object dtype, double* place):
	return place[0]

decl = DDType()
decl.dsize = sizeof(double)
decl.c_pack = <c_pack_t> pack_d
decl.c_unpack = <c_unpack_t> unpack_d
decl.layout = b'd'

declare('d', decl)


### declare float

cdef int pack_f(object dtype, float* place, object obj) except -1:
	place[0] = obj
cdef object unpack_f(object dtype, float* place):
	return place[0]

decl = DDType()
decl.dsize = sizeof(float)
decl.c_pack = <c_pack_t> pack_f
decl.c_unpack = <c_unpack_t> unpack_f
decl.layout = b'f'

declare('f', decl)


### declare int8_t

cdef int pack_b(object dtype, int8_t* place, object obj) except -1:
	place[0] = obj
cdef object unpack_b(object dtype, int8_t* place):
	return place[0]

decl = DDType()
decl.dsize = sizeof(int8_t)
decl.c_pack = <c_pack_t> pack_b
decl.c_unpack = <c_unpack_t> unpack_b
decl.layout = b'b'

declare('b', decl)


### declare uint8_t

cdef int pack_B(object dtype, uint8_t* place, object obj) except -1:
	place[0] = obj
cdef object unpack_B(object dtype, uint8_t* place):
	return place[0]

decl = DDType()
decl.dsize = sizeof(uint8_t)
decl.c_pack = <c_pack_t> pack_B
decl.c_unpack = <c_unpack_t> unpack_B
decl.layout = b'B'

declare('B', decl)


### declare int16_t

cdef int pack_h(object dtype, int16_t* place, object obj) except -1:
	place[0] = obj
cdef object unpack_h(object dtype, int16_t* place):
	return place[0]

decl = DDType()
decl.dsize = sizeof(int16_t)
decl.c_pack = <c_pack_t> pack_h
decl.c_unpack = <c_unpack_t> unpack_h
decl.layout = b'h'

declare('h', decl)


### declare uint16_t

cdef int pack_H(object dtype, uint16_t* place, object obj) except -1:
	place[0] = obj
cdef object unpack_H(object dtype, uint16_t* place):
	return place[0]

decl = DDType()
decl.dsize = sizeof(uint16_t)
decl.c_pack = <c_pack_t> pack_H
decl.c_unpack = <c_unpack_t> unpack_H
decl.layout = b'H'

declare('H', decl)


### declare int32_t

cdef int pack_i(object dtype, int32_t* place, object obj) except -1:
	place[0] = obj
cdef object unpack_i(object dtype, int32_t* place):
	return place[0]

decl = DDType()
decl.dsize = sizeof(int32_t)
decl.c_pack = <c_pack_t> pack_i
decl.c_unpack = <c_unpack_t> unpack_i
decl.layout = b'i'

declare('i', decl)


### declare uint32_t

cdef int pack_I(object dtype, uint32_t* place, object obj) except -1:
	place[0] = obj
cdef object unpack_I(object dtype, uint32_t* place):
	return place[0]

decl = DDType()
decl.dsize = sizeof(uint32_t)
decl.c_pack = <c_pack_t> pack_I
decl.c_unpack = <c_unpack_t> unpack_I
decl.layout = b'I'

declare('I', decl)


### declare int64_t

cdef int pack_l(object dtype, int64_t* place, object obj) except -1:
	place[0] = obj
cdef object unpack_l(object dtype, int64_t* place):
	return place[0]

decl = DDType()
decl.dsize = sizeof(int64_t)
decl.c_pack = <c_pack_t> pack_l
decl.c_unpack = <c_unpack_t> unpack_l
decl.layout = b'l'

declare('l', decl)


### declare uint64_t

cdef int pack_L(object dtype, uint64_t* place, object obj) except -1:
	place[0] = obj
cdef object unpack_L(object dtype, uint64_t* place):
	return place[0]

decl = DDType()
decl.dsize = sizeof(uint64_t)
decl.c_pack = <c_pack_t> pack_L
decl.c_unpack = <c_unpack_t> unpack_L
decl.layout = b'L'

declare('L', decl)

declare(float, declared('d'))
declare(int, declared('l'))
