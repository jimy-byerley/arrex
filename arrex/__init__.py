''' Arrex is a module that allows to create typed arrays much like numpy.ndarray and array.array, but resizeable and using any kind of element.

	The elements must be extension-types (eg. class created in compiled modules) and must have a packed and copyable content: a fixed size and no reference or pointers
	This is meant to ensure that the content of those objects can be copied from the object to the array and back to any object after, or even deleted without any need of calling a constructor or destructor function.
	
	basic usage:
	
		>>> from arrex import *
		>>> a = typedlist([
		...             myclass(...), 
		...             myclass(...),
		...             ], dtype=myclass)
		>>> a[0]
		myclass(...)
	
	in that example, `myclass` can be a primitive numpy type, like `np.float64`
	
		>>> import typedlist.numpy		# this is enabling numpy dtypes for arrex
		>>> typedlist(dtype=np.float64)
		
	it can be a more complex type, from module `pyglm` for instance
	
		>>> import typedlist.glm		# this is enabling glm dtypes for arrex
		>>> typedlist(dtype=glm.vec4)
		
		>>> a = typedlist(dtype=vec3)

	use it as a list
	
		>>> # build from an iterable
		>>> a = typedlist([], dtype=vec3)
		>>>
		>>> # append some data
		>>> a.append(vec3(1,2,3))
		>>>
		>>> # extend with an iterable
		>>> a.extend(vec3(i)  for i in range(5))
		>>>
		>>> len(a)	# the current number of elements
		6
		>>> a.owner	# the current data buffer
		b'.........'
		>>> a[0]
		vec3(1,2,3)
		
		
	Use it as a slice:

		>>> myslice = a[:5]		# no data is copied
		typedlist(....)
	
	Use it as a view on top of a random buffer

		>>> a = np.ones((6,3), dtype='f4')
		>>> myslice = typedlist(a, dtype=vec3)
	
	It does support the buffer protocol, so it can be converted into a great variety of well known arrays, even without any copy

		>>> np.array(typedlist([....]))
	
'''

__all__ = ['typedlist']

from .dtypes import *
from .list import typedlist
from . import numbers
