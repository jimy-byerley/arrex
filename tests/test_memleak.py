from arrex import typedlist
import numpy as np
from copy import deepcopy
import sys
import gc

input('start> ')
buffs = {}

def test_i8():
	buffs[0] = bytes(5)

	a = typedlist([1,2,3])
	buffs[1] = a.owner
	b = a * 5000
	buffs[2] = b.owner

	last = a.owner
	for j in range(500):
		for i in range(10000):
			a.append(i)
		if a.owner is not last:
			buffs[(3,j)] = last = a.owner
			
	buffs[4] = deepcopy(a[:]).owner
	buffs[5] = (a + b).owner
	c = typedlist(np.array([1,2,3], dtype='i8'), dtype='l')
	buffs[6] = c.owner
	buffs[7] = (a + c).owner
	c.extend(a)
	buffs[8] = c.owner
	buffs[9] = typedlist.full(0, 20000)
	buffs[10] = typedlist(i  for i in range(20000))

def test_uvec3():
	import arrex.glm
	from glm import uvec3, vec3, normalize, cross
	buffs[0] = bytes(5)

	a = typedlist([uvec3(1),uvec3(2),uvec3(3)])
	buffs[1] = a.owner
	b = a * 2000
	buffs[2] = b.owner

	last = a.owner
	for j in range(500):
		for i in range(5000):
			a.append(uvec3(i))
		if a.owner is not last:
			buffs[(3,j)] = last = a.owner
			
	buffs[4] = deepcopy(a[:]).owner
	buffs[5] = (a + b).owner
	c = typedlist(np.array([1,2,3], dtype='i8'), dtype='l')
	buffs[6] = c.owner
	buffs[7] = (a + c).owner
	c.extend(a)
	buffs[8] = c.owner
	buffs[9] = typedlist.full(uvec3(0), 2000000).owner
	buffs[10] = typedlist(normalize(cross(vec3(i), vec3(1,2,3)))  for i in range(2000000)).owner

for i in range(10):
	if i:	buffs.clear()
	test_uvec3()
gc.collect()

size = 0
for k,v in buffs.items():
	print('{}:  type={}, size={} M, id=0x{:x}, rc={}'.format(k, type(v), len(v)/2**20, id(v), sys.getrefcount(v)))
	size += len(v)
print('total {} M'.format(size/2**20))
input('consumption> ')

del buffs
gc.collect()
input('exit> ')
