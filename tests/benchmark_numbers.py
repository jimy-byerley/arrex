import arrex
import arrex.numbers
from arrex import *
from time import perf_counter

n = 10000

print('\nget item')

# try the current implementation
a = typedlist.full(1.2, n)
start = perf_counter()
for i in range(n):
	a[i]
print('  cython:\t{:.4e} s'.format(perf_counter()-start))

# try extracting with struct
import struct
struct = struct.Struct('d')
arrex.declare(float, arrex.DTypeFunctions(
			dsize=8, 
			pack=struct.pack,
			unpack=struct.unpack,
			layout=struct.format,
			))
a = typedlist.full(1.2, n)
start = perf_counter()
for i in range(n):
	a[i]
print('  struct:\t{:.4e} s'.format(perf_counter()-start))

# try extracting with ctypes
from ctypes import c_double
arrex.declare(float, arrex.DTypeFunctions(
			dsize=8, 
			pack=lambda o: bytes(c_double(o)), 
			unpack=lambda b: c_double.from_buffer_copy(b).value, 
			layout='d',
			))
a = typedlist.full(1.2, n)
start = perf_counter()
for i in range(n):
	a[i]
print('  ctypes:\t{:.4e} s'.format(perf_counter()-start))

# try access in numpy array
import numpy as np
a = np.ones((n,)) * 1.2
start = perf_counter()
for i in range(n):
	a[i]
print('  numpy:\t{:.4e} s'.format(perf_counter()-start))

# try access in array.array
import array
a = array.array('d', [1.2]) * n
start = perf_counter()
for i in range(n):
	a[i]
print('  array:\t{:.4e} s'.format(perf_counter()-start))
