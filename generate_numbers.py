numbers = open('arrex/numbers.pyx', 'w')

numbers.write('''# cython: language_level=3, cdivision=True

cimport cython
from cpython cimport PyObject
from libc.stdint cimport *
from .dtypes cimport *

cdef DDType decl
''')

template = '''

### declare {ctype}

cdef int pack_{layout}(PyObject* dtype, {ctype}* place, object obj) except -1:
	place[0] = obj
cdef object unpack_{layout}(PyObject* dtype, {ctype}* place):
	return place[0]

decl = DDType()
decl.dsize = sizeof({ctype})
decl.c_pack = <c_pack_t> pack_{layout}
decl.c_unpack = <c_unpack_t> unpack_{layout}
decl.layout = b'{layout}'

declare('{layout}', decl)
'''

for layout, ctype in [
		('d', 'double'),
		('f', 'float'),
		('b', 'int8_t'),
		('B', 'uint8_t'),
		('h', 'int16_t'),
		('H', 'uint16_t'),
		('i', 'int32_t'),
		('I', 'uint32_t'),
		('l', 'int64_t'),
		('L', 'uint64_t'),
		]:
	numbers.write(template.format(layout=layout, ctype=ctype))
	
numbers.write('''
declare(float, declared('d'))
declare(int, declared('l'))
''')
