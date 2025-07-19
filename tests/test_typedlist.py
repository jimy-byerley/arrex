import glm
import arrex
from pnprint import nprint

arrex.declare(glm.vec4, arrex.DDTypeExtension(glm.vec4, 'ffff'))
arrex.declare(glm.dvec4, arrex.DDTypeExtension(glm.dvec4, 'dddd', glm.dvec4))
arrex.declare(glm.mat4, arrex.DDTypeExtension(glm.mat4))

n = 20

def test_create():
	print('\n* creating')
	array = arrex.typedlist([glm.dvec4(-2,-3,-4,-5)], dtype=glm.dvec4)

	print('\n* full')
	a2 = arrex.typedlist.full(glm.vec4(2), 4)
	assert len(a2) == 4
	assert a2[-1] == glm.vec4(2)

def test_insertion():
	array = arrex.typedlist([glm.dvec4(-2,-3,-4,-5)], dtype=glm.dvec4)

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

def test_access():
	array = arrex.typedlist(range(n+3), dtype=glm.dvec4)
	
	print('\n* accessing')
	for i in range(len(array)):
		print(array[i])

	print('\n* len', len(array))
	print('\n* element type', type(array[n]))
	print('\n* operation', array[n] + glm.dvec4(5,6,7,8))

def test_iter():
	array = arrex.typedlist(range(n), dtype=glm.dvec4)
	for i,v in zip(range(10), array):
		print(i,v)

def test_attributes():
	array = arrex.typedlist(range(n), dtype=glm.dvec4)
	print('  size', array.size)
	print('  allocated', array.allocated)
	print('  dtype', array.dtype)

# check what is exposed as public members
def test_api():
	array = arrex.typedlist(range(n), dtype=glm.dvec4)
	print('\n* methods')
	print(dir(array))

def test_buffer_protocol():
	array = arrex.typedlist(range(n), dtype=glm.dvec4)
	nprint(memoryview(array))
	nprint(memoryview(array[:10]))
	#print(memoryview(array).cast('B').cast('H'))

def test_slicing():
	array = arrex.typedlist(range(n+3), dtype=glm.dvec4)
	
	pick = array[10:n]
	assert len(pick) == n-10
	nprint(pick)
	pick = array[2:n][1:3]
	assert len(pick) == 2
	nprint(pick)
	for e in array[10:n]: pass

	array[2:3] = [glm.dvec4(-42), glm.dvec4(-43), glm.dvec4(-44)]
	assert len(array) == n+5

def test_conversion():
	import numpy.core as np
	array = arrex.typedlist(range(n), dtype=glm.dvec4)
	cvt = np.array(array)
	assert cvt.shape[0] == len(array)
	nprint(cvt)

def test_concatenation():
	array = arrex.typedlist(range(n), dtype=glm.dvec4)
	array += array[-5:]
	nprint(array)
	nprint(array + array[-5:])
	nprint(array[:5] + array[-5:])

def test_copy_protocol():
	from copy import copy, deepcopy
	
	array = arrex.typedlist(range(n), dtype=glm.dvec4)
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

	array = arrex.typedlist([1,2,3,4], dtype='I')
	reloaded = pickle.loads(pickle.dumps(array))
	assert reloaded == array


