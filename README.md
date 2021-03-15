Arrex
-----

Arrex is a module that allows to create type arrays much like numpy.ndarray and array.array, but resizeable and using any kind of element.

The elements must be extension-types (eg. class created in compiled modules) and must have a packed and copyable content: a fixed size and no reference or pointers.

### basic usage:

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
	
it can be a more complex type, from module `pyglm` for instance

	>>> import xarray.glm		# this is enabling glm dtypes for arrex
	>>> xarray(dtype=glm.vec4)

	
`xarray` is a dynamically sized, borrowing array, which mean the internal buffer of data is reallocated on insertion, but can be used to view and extract from any buffer.
		
### Use it as a list:

	>>> a = xarray(dtype=vec3)
	
	# build from an iterable
	>>> a = xarray([], dtype=vec3)
	
	# append some data
	>>> a.append(vec3(1,2,3))
	
	# extend with an iterable
	>>> a.extend(vec3(i)  for i in range(5))
	
	>>> len(a)	# the current number of elements
	6
	
	>>> a.owner	# the current data buffer
	b'.........'
	
### Use it as a slice:

	>>> myslice = a[:5]		# no data is copied
	xarray(....)
	
### Use it as a view on top of a random buffer

	>>> a = np.ones((6,3), dtype='f4')
	>>> myslice = xarray(a, dtype=vec3)
	
### buffer protocol

It does support the buffer protocol, so it can be converted in a great variety of well known arrays, even without any copy

	>>> np.array(xarray([....]))

