import glm
import arrex as nx
from nprint import nprint

nx.declare(glm.vec4, nx.DTypeExtension(glm.vec4, 'ffff'))
nx.declare(glm.dvec4, nx.DTypeExtension(glm.dvec4, 'dddd', glm.dvec4))
nx.declare(glm.mat4, nx.DTypeExtension(glm.mat4))

n = 20

print('\n* creating')
array = nx.typedlist([glm.dvec4(-2,-3,-4,-5)], dtype=glm.dvec4)

print('\n* full')
a2 = nx.typedlist.full(glm.vec4(2), 4)
assert len(a2) == 4
assert a2[-1] == glm.vec4(2)

print('\n* reserving')
array.reserve(1)
assert array.capacity() >= 2

print('\n* append non dtype')
array.append((5,6,7,2))
assert len(array) == 2
assert array[1] == glm.dvec4(5,6,7,2)

print('\n* appending')
for i in range(n):
	array.append(glm.dvec4(i+2))
assert len(array) == n+2
	
print('\n* inserting')
for i in reversed(range(n)):
	array.insert(i, glm.dvec4(-1))
assert len(array) == 2*n+2	
assert array[-4] == glm.dvec4(-1)
assert array[-2] != glm.dvec4(-1)


print('\n* accessing')
for i in range(len(array)):
	print(array[i])

print('\n* len', len(array))
print('\n* element type', type(array[n]))
print('\n* operation', array[n] + glm.dvec4(5,6,7,8))

print('\n* iter')
for i,v in zip(range(10), array):
	print(i,v)

print('\n* members')
print('  size', array.size)
print('  allocated', array.allocated)
print('  dtype', array.dtype)

# check what is exposed as public members
print('\n* methods')
print(dir(array))

# buffer protocol
print('\n* buffer')
nprint(memoryview(array))
nprint(memoryview(array[:10]))
#print(memoryview(array).cast('B').cast('H'))

# test slicing
print('\n* slice')
pick = array[10:n]
assert len(pick) == n-10
nprint(pick)
pick = array[2:n][1:3]
assert len(pick) == 2
nprint(pick)
for e in array[10:n]: pass

# test array conversion
print('\n* np array')
import numpy.core as np
cvt = np.array(array)
assert cvt.shape[0] == len(array)
nprint(cvt)


# test array and slices concatenation
print('\n* concat')
array += array[-5:]
nprint(array)
nprint(array + array[-5:])
nprint(array[:5] + array[-5:])


# test copy protocol
from copy import copy, deepcopy
array = array[:3]

print('\n* copy')
copied = copy(array)
nprint(copied)
assert copied == array
copied[0] = glm.dvec4(42)
assert copied == array
copied.append(glm.dvec4(42))
assert copied != array

print('\n* deepcopy')
copied = deepcopy(array)
nprint(copied)
assert copied == array
copied[0] = glm.dvec4(43)
assert copied != array

# test pickle serialization
import pickle
print('\n* pickle')
reloaded = pickle.loads(pickle.dumps(array))
assert reloaded == array


