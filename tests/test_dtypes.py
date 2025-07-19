from arrex import *
from pnprint import nprint


def test_builtins_numbers():
	# python builtin numbers
	a = typedlist(dtype='f')
	a.append(1)
	a.append(1.2)
	nprint('f', a.ddtype, a)
	assert type(a[0]) is float

	a = typedlist(dtype='d')
	b = typedlist(dtype=float)
	assert a.dtype is b.dtype

	a = typedlist(dtype='i')
	a.append(1)
	a.append(1.2)
	nprint('i', a.ddtype, a)
	assert type(a[0]) is int

	a = typedlist(dtype='h')
	a.append(1)
	a.append(4)
	nprint('h', a.ddtype, a)
	assert len(a) == 2
	assert a[0] == 1
	assert type(a[0]) == int
	assert a.dtype == 'h'

def test_type_inference():
	# test automatic type deduction
	a = typedlist([1, 2, 3, 5])
	assert a.dtype == 'l'
	assert len(a) == 4
	nprint('auto', a.ddtype, a)

def test_struct():
	# struct
	a = typedlist(dtype='fxBh')
	a.append((1.2, 3, -2))
	a.append((1.2, 1, -2))
	nprint('struct', a.ddtype, a)
	assert a[1][1:] == (1, -2)
	assert type(a[1]) is tuple
	assert a.dtype == 'fxBh'

def test_ctypes():
	import ctypes

	class test_structure(ctypes.Structure):
		_fields_ = [('x', ctypes.c_int),
					('y', ctypes.c_float),
					]
		def __repr__(self):
			return '(x={}, y={})'.format(self.x, self.y)

	a = typedlist(dtype=test_structure)
	a.append(test_structure(y=1.2, x=1))
	a.append(test_structure(y=1, x=-2))
	nprint('ctype structure', a.ddtype, a)
	assert type(a[0]) is test_structure
	assert a.dtype is test_structure

	a = typedlist(dtype=ctypes.c_int8)
	a.append(ctypes.c_int8(8))
	a.append(ctypes.c_int8(2))
	nprint('ctype primitive', a.ddtype, a)

def test_class():
	# python native class
	import struct

	class test_class:
		__packlayout__ = 'dd'
		_struct = struct.Struct(__packlayout__)
		
		def __init__(self, x, y):
			self.x = x
			self.y = y
		
		def __bytes__(self):
			return self._struct.pack(self.x, self.y)
		@classmethod
		def frombytes(cls, b):
			return cls(*cls._struct.unpack(b))
			
		def __repr__(self):
			return '(x={}, y={})'.format(self.x, self.y)

	a = typedlist(dtype=test_class)
	a.append(test_class(1.2, 2))
	a.append(test_class(1.2, 1))
	nprint('native class', a.ddtype, a)
	assert a.ddtype.dsize == 16
	assert a[0].x == a[1].x
	assert type(a[0]) is test_class
	assert a.dtype is test_class
