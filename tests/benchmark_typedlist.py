import numpy.core as np
import arrex as nx
from glm import fvec3, dvec3, dmat4
from time import perf_counter

nx.declare(fvec3, nx.DTypeExtension(fvec3, 'fff', fvec3))
nx.declare(dvec3, nx.DTypeExtension(dvec3, 'ddd', dvec3))
nx.declare(dmat4, nx.DTypeExtension(dmat4, 'd'*16, dmat4))
n = 10000

print('benchmark for arrays of {} elements'.format(n))


print('\nempty creation')

start = perf_counter()
poa = [None] * n
print('  list: \t{:.4e} s'.format(perf_counter()-start))

start = perf_counter()
npa = np.empty((n,), dtype='3f8')
print('  numpy:\t{:.4e} s'.format(perf_counter()-start))

start = perf_counter()
nxa = nx.typedlist(dtype=dvec3, reserve=n)
print('  arrex:\t{:.4e} s'.format(perf_counter()-start))


print('\nfilled creation')

start = perf_counter()
poa = [dvec3(1)  for i in range(n)]
print('  list: \t{:.4e} s'.format(perf_counter()-start))

start = perf_counter()
npa = np.ones((n,), dtype='3f8')
print('  numpy:\t{:.4e} s'.format(perf_counter()-start))

start = perf_counter()
nxa = nx.typedlist.full(dvec3(1), n)
print('  arrex:\t{:.4e} s'.format(perf_counter()-start))


print('\nset item')

e = dvec3(1)
start = perf_counter()
for i in range(n):
	poa[i] = e
print('  list: \t{:.4e} s'.format(perf_counter()-start))

e = (1,1,1)
start = perf_counter()
for i in range(n):
	npa[i] = e
print('  numpy:\t{:.4e} s'.format(perf_counter()-start))

e = dvec3(1)
start = perf_counter()
for i in range(n):
	nxa[i] = e
print('  arrex:\t{:.4e} s'.format(perf_counter()-start))


print('\nget item')

start = perf_counter()
for i in range(n):
	dvec3(1)
print('  creation:\t{:.4e} s'.format(perf_counter()-start))

start = perf_counter()
for i in range(n):
	poa[i]
print('  list: \t{:.4e} s'.format(perf_counter()-start))

start = perf_counter()
for i in range(n):
	npa[i]
print('  numpy:\t{:.4e} s'.format(perf_counter()-start))

start = perf_counter()
for i in range(n):
	nxa[i]
print('  arrex:\t{:.4e} s'.format(perf_counter()-start))


print('\ninto memoryview')

start = perf_counter()
for i in range(n):
	memoryview(npa)
print('  numpy:\t{:.4e} s'.format(perf_counter()-start))

start = perf_counter()
for i in range(n):
	memoryview(nxa)
print('  arrex:\t{:.4e} s'.format(perf_counter()-start))


print('\nconcatenation')

start = perf_counter()
poa + poa
print('  list: \t{:.4e} s'.format(perf_counter()-start))

start = perf_counter()
np.concatenate([npa, npa])
print('  numpy:\t{:.4e} s'.format(perf_counter()-start))

start = perf_counter()
nxa + nxa
print('  arrex:\t{:.4e} s'.format(perf_counter()-start))
