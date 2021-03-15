Arrex
-----

Arrex is a module that allows to create typed arrays much like `numpy.ndarray` and `array.array`, but resizeable and using any kind of element, not only numbers.

The elements must be extension-types (eg. class created in compiled modules) and must have a packed and copyable content: a fixed size and no reference or pointers.

### basic usage:

```python
>>> from arrex import *
>>> a = typedlist([
			myclass(...), 
			myclass(...),
			], dtype=myclass)
>>> a[0]
myclass(...)
```

in that example, `myclass` can be a primitive numpy type, like `np.float64`

```python
>>> import typedlist.numpy		# this is enabling numpy dtypes for arrex
>>> typedlist(dtype=np.float64)
```
	
it can be a more complex type, from module `pyglm` for instance

```python
>>> import typedlist.glm		# this is enabling glm dtypes for arrex
>>> typedlist(dtype=glm.vec4)
```

	
`typedlist` is a dynamically sized, borrowing array, which mean the internal buffer of data is reallocated on insertion, but can be used to view and extract from any buffer.
		
### Use it as a list:

```python
>>> a = typedlist(dtype=vec3)

# build from an iterable
>>> a = typedlist([], dtype=vec3)

# append some data
>>> a.append(vec3(1,2,3))

# extend with an iterable
>>> a.extend(vec3(i)  for i in range(5))

>>> len(a)	# the current number of elements
6

>>> a.owner	# the current data buffer
b'.........'
```
	
### Use it as a slice:

```python
>>> myslice = a[:5]		# no data is copied
typedlist(....)
```
	
### Use it as a view on top of a random buffer

```python
>>> a = np.ones((6,3), dtype='f4')
>>> myslice = typedlist(a, dtype=vec3)
```
	
### buffer protocol

It does support the buffer protocol, so it can be converted in a great variety of well known arrays, even without any copy

```python
>>> np.array(typedlist([....]))
```
	
	
## performances

Time performances comparison between `list`,  `numpy.ndarray`,  and `arrex.typedlist`  (see [benchmark](benchmark_typedlist.py) )

execution time (s) for 10k elements (dvec3)

	set item
	list:         2.31e-03
	numpy:        8.29e-03
	arrex:        2.29e-03  (3x faster then numpy)

	get item
	list:         5.47e-04
	numpy:        1.54e-03
	arrex:        7.47e-04  (2x faster than numpy)


	
## Roadmap

This module is currently a 4 days first draft, but there is additionnal features planned:

- typedarray

	a n-dim array view much like numpy arrays but using dtypes as in `typedlist`.
	Its purpose is mostly to access its items with n-dim indices and slices.
	
- dtypes for mainstream primitives 

	(ints and floats) independant from numpy

- a ufunc system
	
	to collect and put defaults to any kind of array scale operations, like `__add__`, `__mul__`, `__matmul__`, ... The goal would be to have a standard way to apply any function to every element of one or more array, that defaults to the python implementation, but can be overloaded with a compiled implementation
	
- dtypes defined from python

	current dtypes are extension types (written in C), it could great to create dtypes from python also
	
	
- maybe 

	even extend to the complete API of [numcy](https://github.com/jimy-byerley/numcy/blob/master/proposal.md)

