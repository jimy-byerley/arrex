import glm
import arrex as nx
from nprint import nprint

nx.declare(glm.vec4, None, 'ffff')
nx.declare(glm.dvec4, glm.dvec4, 'dddd')
nx.declare(glm.mat4, glm.mat4, None)

n = 20

print('\ncreating')
array = nx.typedlist([glm.dvec4(-2,-3,-4,-5)], dtype=glm.dvec4)

print('\nreserving')
array.reserve(1)

print('\nappend non dtype')
array.append((5,6,7,2))

print('\nappending')
for i in range(n):
	array.append(glm.dvec4(i+2))
	
print('\ninserting')
for i in reversed(range(n)):
	array.insert(i, glm.dvec4(-1))
	

print('\naccessing')
for i in range(len(array)):
	print(array[i])

print('\nlen', len(array))
print('\nelement type', type(array[n]))
print('\noperation', array[n] + glm.dvec4(5,6,7,8))

print('\niter')
for i,v in zip(range(10), array):
	print(i,v)

print('\nmembers')
print('  size', array.size)
print('  allocated', array.allocated)
print('  dtype', array.dtype)

print('\nmethods')
print(dir(array))

print('\nbuffer')
nprint(memoryview(array))
nprint(memoryview(array[:10]))
#print(memoryview(array).cast('B').cast('H'))

print('\nslice')
nprint(array[10:n])
nprint(array[2:n][1:3])
for e in array[10:n]: pass

print('\nnp array')
import numpy.core as np
nprint(np.array(array))


print('\nconcat')
array += array[-5:]
nprint(array)
nprint(array + array[-5:])
nprint(array[:5] + array[-5:])

from copy import copy, deepcopy
import pickle

array = array[:3]
nprint('copy', copy(array))
nprint('deepcopy', deepcopy(array))

reloaded = pickle.loads(pickle.dumps(array))
assert reloaded == array


