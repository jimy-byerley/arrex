Arrex
-----

- [documentation](https://arrex.readthedocs.io/)
- [repository](https://github.com/jimy-byerley/pymadcad)

[![support-version](https://img.shields.io/pypi/pyversions/arrex.svg)](https://img.shields.io/pypi/pyversions/arrex)
[![PyPI version shields.io](https://img.shields.io/pypi/v/arrex.svg)](https://pypi.org/project/arrex/)
[![Documentation Status](https://readthedocs.org/projects/arrex/badge/?version=latest)](https://arrex.readthedocs.io/en/latest/?badge=latest)

Arrex is a module that allows to create typed arrays much like `numpy.ndarray` and `array.array`, but resizeable and using any kind of element, not only numbers. Its dtype system is extremely flexible and makes it ideal to work and share structured data with compiled code.

The elements can be many different things, there is just 2 requirements:

- they must be of a fixed binary size
- they must be byte copiable, therefore without any reference or pointer to something else

### interests

- much smaller memory footprint (an arrex array is at most 30x smaller than pure python data storage)
- content can be directly shared with compiled code which improves computation performances
- slice & view without a copy
- compatible with standard python libraries

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
>>> import arrex.numpy		# this is enabling numpy dtypes for arrex
>>> typedlist(dtype=np.float64)
```

it can be a more complex type, from module `pyglm` for instance

```python
>>> import arrex.glm		# this is enabling glm dtypes for arrex
>>> typedlist(dtype=glm.vec4)
```

`typedlist` is a dynamically sized, borrowing array, which mean the internal buffer of data is reallocated on append, but can be used to view and extract from any buffer without a copy.

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

>>> a[0]
vec3(1,2,3)
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

It does support the buffer protocol, so it can be converted into a great variety of well known arrays, even without any copy

```python
>>> np.array(typedlist([....]))
```

### Which dtype is allowed

answer is: *whatever you want*, but here is some examples:

```python
# an extension type, previously declared
typedlist(dtype=glm.vec3)

# a Struct
typedlist(dtype='ffxI')

# a ctype
typedlist(dtype=ctypes.c_int*5)

# a pure python class
class test_class:
    __packlayout__ = 'ff'
    _struct = struct.Struct(__packlayout__)

    def __init__(self, x, y):
        self.x = x
        self.y = y

    def __bytes__(self):
        return self._struct.pack(self.x, self.y)
    @classmethod
    def frombytes(cls, b):
        return cls(*cls._struct.unpack(b))

typedlist(dtype=test_class)

# and so much more !
```



## performances

Time performances comparison between `list`,  `numpy.ndarray`,  and `arrex.typedlist`  (see [benchmark](benchmark_typedlist.py) )

execution time (s) for 10k elements (dvec3)

	set item
	  list:         7.9847e-04 s
	  numpy:        1.2727e-02 s
	  arrex:        1.0481e-03 s  (10x faster than numpy)
	
	get item
	  creation:     1.0655e-03 s
	  list:         5.1503e-04 s
	  numpy:        1.8619e-03 s
	  arrex:        8.0111e-04 s   (2x faster than numpy)


​	
## Roadmap

There is additionnal features planned, but no precise schedul yet:

- typedarray

	a n-dim array view much like numpy arrays but using dtypes as in `typedlist`.
	Its purpose is mostly to access its items with n-dim indices and slices.
	
- a ufunc system
	
	to collect and put defaults to any kind of array scale operations, like `__add__`, `__mul__`, `__matmul__`, ... The goal would be to have a standard way to apply any function to every element of one or more array, that defaults to the python implementation, but can be overloaded with a compiled implementation
	
- maybe 

	even extend to the complete API of [numcy](https://github.com/jimy-byerley/numcy/blob/master/proposal.md)

