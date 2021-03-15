import numpy.core as np
import xarray as nx
from glm import fvec3, dvec3, dmat4
from time import perf_counter

nx.declare(fvec3, fvec3, 'fff')
nx.declare(dvec3, dvec3, 'ddd')
nx.declare(dmat4, dmat4, 'd'*16)
n = 10000


print('\ncreation')

start = perf_counter()
poa = [None] * n
print('  list:\t{:.4e}'.format(perf_counter()-start))

start = perf_counter()
npa = np.empty((n,), dtype='3f8')
print('  numpy:\t{:.4e}'.format(perf_counter()-start))

start = perf_counter()
nxa = nx.xarray(dtype=dvec3, reserve=n)
print('  kustom:\t{:.4e}'.format(perf_counter()-start))

for i in range(n):
	nxa.append(dvec3(0))


print('\nset item')

start = perf_counter()
for i in range(n):
	poa[i] = dvec3(i,i,i)
print('  list:\t{:.4e}'.format(perf_counter()-start))

start = perf_counter()
for i in range(n):
	npa[i] = (i,i,i)
print('  numpy:\t{:.4e}'.format(perf_counter()-start))

start = perf_counter()
for i in range(n):
	nxa[i] = dvec3(i,i,i)
print('  kustom:\t{:.4e}'.format(perf_counter()-start))


print('\nget item')

start = perf_counter()
for i in range(n):
	poa[i]
print('  list:\t{:.4e}'.format(perf_counter()-start))

start = perf_counter()
for i in range(n):
	npa[i]
print('  numpy:\t{:.4e}'.format(perf_counter()-start))

start = perf_counter()
for i in range(n):
	nxa[i]
print('  kustom:\t{:.4e}'.format(perf_counter()-start))


print('\ninto memoryview')

start = perf_counter()
for i in range(n):
	memoryview(npa)
print('  numpy:\t{:.4e}'.format(perf_counter()-start))

start = perf_counter()
for i in range(n):
	memoryview(nxa)
print('  kustom:\t{:.4e}'.format(perf_counter()-start))


print('\nconxatenation')

start = perf_counter()
poa + poa
print('  list:\t{:.4e}'.format(perf_counter()-start))

start = perf_counter()
npa + npa
print('  numpy:\t{:.4e}'.format(perf_counter()-start))

start = perf_counter()
nxa + nxa
print('  kustom:\t{:.4e}'.format(perf_counter()-start))
