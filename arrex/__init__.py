''' Arrex is a module that allows to create type arrays much like numpy.ndarray and array.array, but using any kind of element.

	The elements must be extension-types (eg. class created in compiled modules) and must have a packed and copyable content: a fixed size and no reference or pointers
	This is meant to ensure that the content of those objects can be copied from the object to the array and back to any object after, or even deleted without any need of calling a constructor or destructor function.
	
	basic usage:
	
		>>> from arrex import *
		>>> a = xarray([
		            myclass(...), 
		            myclass(...),
		            ], dtype=myclass)
		>>> a[0]
		myclass(...)
	
	in that example, `myclass` can be a primitive numpy type, like `np.float64`
	
		>>> import xarray.numpy		# this is enabling numpy dtypes for arrex
		>>> xarray(dtype=np.float64)
		
	it can be a more complex type, with module `glm` for instance
	
		>>> import xarray.glm		# this is enabling glm dtypes for arrex
		>>> xarray(dtype=glm.vec4)
	
	
	if you want to use a type that you know to satisfy the requirements to be packed and noref, you can declare it as a valid dtype:
	
		>>> packed_format = 'xxfiB'	# format as described in module 'struct'
		>>> arrex.declare(mytype, mytype, packed_format)	# (myclass, constructor, format)
'''

__all__ = ['xarray']

from ._arrex import *
