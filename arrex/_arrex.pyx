# cython: language_level=3, cdivision=True

cimport cython
from cpython cimport PyObject, PyTypeObject, Py_buffer, PyObject_Length, Py_INCREF
from cpython.mem cimport PyMem_Malloc, PyMem_Realloc, PyMem_Free
from cpython.buffer cimport PyBUF_SIMPLE, PyBUF_ND, PyBUF_FORMAT, PyObject_CheckBuffer, PyObject_GetBuffer, PyBuffer_Release
from libc.string cimport memcpy, memmove, memcmp

import struct
from pickle import PickleBuffer

cdef extern from "Python.h":
	object PyBytes_FromStringAndSize(const char *v, Py_ssize_t len)
	char *PyBytes_AsString(object)
	char *PyBytes_AS_STRING(object)
	int PySlice_Unpack(object slice, Py_ssize_t *start, Py_ssize_t *stop, Py_ssize_t *step)
	Py_ssize_t PySlice_AdjustIndices(Py_ssize_t length, Py_ssize_t *start, Py_ssize_t *stop, Py_ssize_t step)
	Py_ssize_t PyObject_LengthHint(object o, Py_ssize_t default)
	int PyNumber_Check(PyObject *o)


# this is to avoid the issue around Py_buffer.obj = pyobject, which in cython would try to decref the initially NULL value
# so the value needs to be set using that function when set the first time
cdef extern from *:
	"""
	void assign_buffer_obj(Py_buffer* buf, PyObject* o) {
		Py_INCREF(o);
		buf->obj = o;
	}
	"""
	void assign_buffer_obj(Py_buffer* buf, object o)



ctypedef int (*c_pack_t) (PyObject*, void*, PyObject*)
ctypedef PyObject* (*c_unpack_t) (PyObject*, void*)

cdef class DType:
	''' base class for a dtype, But you should use on of its specialization instead '''
	cdef public size_t dsize
	cdef c_pack_t c_pack
	cdef c_unpack_t c_unpack
	cdef public bytes layout
	cdef public object key
	cdef public constructor
	
	def __init__(self):
		raise TypeError('DType must not be instantiated, use one of its subclasses instead.')
	
	def __repr__(self):
		if isinstance(self.key, type):
			return '<dtype {}>'.format(self.key.__name__)
		elif isinstance(self.key, str):
			return '<dtype {}>'.format(repr(self.key))
		else:
			return object.__repr__(self)
	

def DTypeClass(type, constructor=None):
	''' create a dtype from a python class (can be a pure python class) 
		
		the given type must have the following attributes:
		
			- `frombytes` or `from_bytes` or `from_buffer`
			
				static method that initialize the type from bytes
				
			- `__bytes__` or `tobytes` or `to_bytes`
				
				method that converts to bytes, the returned byte must always be of the same size
			
			- `__packlayout__`     (optional)  string or bytes giving binary format returned by `__bytes__`, it must follow the specifications of module `struct`
			- `__packsize__`       (optional)  defines the byte size returned by `__bytes__`, optional if `__packlayout__` is provided
	'''
	layout = getattr(type, '__packlayout__')
	dsize = getattr(type, '__packsize__')
	if not dsize:
		dsize = struct.calcsize(layout)
	if not dsize:
		raise ValueError('dsize must not be null, __packlayout__ or __packsize__ must be correctly defined in the given type')
	
	pack = getattr(type, '__bytes__', None) or getattr(type, 'tobytes', None) or getattr(type, 'to_bytes', None)
	if not pack:
		raise TypeError("the given type must have a method '__bytes__', 'tobytes', or 'to_bytes'")
	
	unpack = getattr(type, 'frombytes', None) or getattr(type, 'from_bytes', None) or getattr(type, 'from_buffer', None)
	if not unpack:
		raise TypeError("the given type must have a method 'frombytes', 'from_bytes', or 'from_buffer'")
	
	return DTypeFunctions(dsize, pack, unpack, layout, constructor)
	

cdef class DTypeFunctions(DType):
	''' create a dtype from pure python pack and unpack functions '''
	cdef public object pack
	cdef public object unpack
	
	def __init__(self, dsize, pack, unpack, layout=None, constructor=None):
		if not callable(pack) or not callable(unpack):
			raise TypeError('pack and unpack must be callables')
			
		if layout is not None:
			if isinstance(layout, str):
				layout = layout.encode()
			elif not isinstance(layout, bytes):
				layout = bytes(layout)
			
			fmtsize = struct.calcsize(layout)
			if dsize is not None and dsize != fmtsize:
				raise ValueError('dsize must match layout size')
		elif dsize is None:
			raise ValueError('dsize must be provided or deduced from a given layout')
			
		self.dsize = dsize
		self.c_pack = <c_pack_t> self._func_pack
		self.c_unpack = <c_unpack_t> self._func_unpack
		self.layout = layout
		self.constructor = constructor
		self.pack = pack
		self.unpack = unpack
		
	cdef int _func_pack(self, void* place, object obj) except -1:
		packed = self.pack(obj)
		if not isinstance(packed, bytes):
			raise TypeError('pack must provide a bytes object')
		if len(packed) < <ssize_t> self.dsize:
			raise ValueError('the dumped bytes length {} does not match dsize {}'.format(len(packed), self.dtype.dsize))
		
		memcpy(place, PyBytes_AsString(obj), self.dsize)
	
	cdef object _func_unpack(self, void* place):
		return self.unpack(PyBytes_FromStringAndSize(<char*>place, self.dsize))
		
		
	def __reduce_ex__(self, protocol):
		''' allow serialization of the dtype with the array (particularly useful for anonymous dtypes) '''
		return type(self), (self.dsize, self.pack, self.unpack, self.layout, self.constructor)
		
		
cdef class DTypeExtension(DType):
	''' create a dtype for a C extension type.
	
		This is the most efficient kind of dtype in term of operating time.
		
		In order to put an extension object into an array, it satisfy the following conditions:
		
		- have fixed size known at the time of dtype creation (so any array element has the same)
		- contain only byte copiable data (so nothing particular is done when copying/destroying the objects)
		
		WARNING:  These conditions MUST be ensured by the user when declaring an extension type as a dtype
	'''
	cdef public type type
	
	def __init__(self, type ext, layout=None, constructor=None):
		cdef ssize_t fmtsize, packsize
	
		if not isinstance(ext, type):
			raise TypeError('dtype must be a type')
		#if constructor is not None and not callable(constructor):
			#raise TypeError('constructor must be a callable returning an instance of dtype')
			
		packsize = (<PyTypeObject*> ext).tp_basicsize - sizeof(_head)
		if layout is not None:
			if isinstance(layout, str):
				layout = layout.encode()
			elif not isinstance(layout, bytes):
				layout = bytes(layout)
			
			fmtsize = struct.calcsize(layout)
			if packsize < fmtsize:
				raise ValueError('format describes a too big structure for the given dtype')
		else:
			fmtsize = 0
		
		self.dsize = fmtsize or packsize
		if not self.dsize:
			raise TypeError('dsize cannot be 0')
		
		self.c_pack = <c_pack_t> self._ext_pack
		self.c_unpack = <c_unpack_t> self._ext_unpack
		self.layout = layout
		self.constructor = constructor
		self.type = ext
		
	cdef void * _raw(self, obj):
		return (<void*><PyObject*> obj) + (<PyTypeObject*>self.type).tp_basicsize - self.dsize
	
	cdef int _ext_pack(self, void* place, object obj) except -1:
		memcpy(place, self._raw(obj), self.dsize)
		
	cdef object _ext_unpack(self, void* place):
		new = (<PyTypeObject*>self.type).tp_new(self.type, _empty, None)
		memcpy(self._raw(new), place, self.dsize)
		return new
		
	def __reduce_ex__(self, protocol):
		''' allow serialization of the dtype with the array (particularly useful for anonymous dtypes) '''
		return type(self), (self.type, self.layout, self.constructor)

		
		

# dictionnary of compatible packed types
cdef dict _declared = {}	# {python type: dtype}


cpdef into(obj, DType target):
	''' convert an object into the target type, using the declared constructor '''
	if type(obj) is target.key:		return obj
	
	if target.constructor is None:	
		raise TypeError('cannot implicitely convert {} into {}'.format(
								type(obj).__name__, 
								target.__name__,
								))
	return target.constructor(obj)
	
cpdef declare(key, DType dtype):
	''' declare(dtype, constructor=None, format=None)
	
		declare a new dtype 
	'''
	dtype.key = key
	_declared[key] = dtype
	
def declared(key):
	''' return the content of the declaration for the givne dtype, if not declared it will return None '''
	if isinstance(key, DType):
		return key
	else:
		return _declared.get(key)

	

# create an empty object to easily get the PyObject head size
cdef class _head:
	''' implementation purpose only '''
	pass

# empty tuple, reused to fasten some calls
cdef tuple _empty = ()



cdef class typedlist:
	''' list-like array that stores objects as packed data. 
		The objects added must necessarily be packed objects (builtin objects with no references).
		
		This is a dynamically sized, borrowing array, which mean the internal buffer of data is reallocated on insertion, but can be used to view and extract from any buffer.
		
		Methods added to the signature of list:
		
			reserve(n)            reallocate if necessary to make sure n elements can 
			                      be inserted without reallocation
			capacity() -> int     return the current number of elements that can be 
			                      contained without reallocation
			shrink()              shorten the allocated memory to fit the current content
			
			also the slices do not copy the content
		
		
		Use it as a list:
		
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
			
		Use it as a slice:
		
			# no data is copied
			>>> myslice = a[:5]
			typedlist(....)
			
		Use it as a view on top of a random buffer
		
			>>> a = np.ones((6,3), dtype='f4')
			>>> myslice = typedlist(a, dtype=vec3)
			
		It does support the buffer protocol, so it can be converted in a great variety of well known arrays, even without any copy
		
			>>> np.array(typedlist([....]))
		
		
		Constructors:
		
			typedlist()
			typedlist(dtype, reserve=None)
			typedlist(iterable, dtype, reserve=None)
			typedlist(buffer, dtype)
	'''

	cdef void *ptr
	cdef readonly size_t size
	cdef readonly size_t allocated
	
	cdef DType dtype
	
	cdef readonly object owner
	
	@property
	def dtype(self):
		return self.dtype.key or self.dtype
		
	@property
	def spec(self):
		return self.dtype
	

	def __init__(self, iterable=None, object dtype=None, size_t reserve=0):
		# look at the type of the first element
		first = None
		if not dtype:
			try:
				if isinstance(iterable, type) and not dtype:
					iterable, dtype = None, iterable
				elif hasattr(iterable, '__next__'):
					first = next(iterable)
					dtype = type(first)
				elif hasattr(iterable, '__iter__'):
					dtype = type(next(iter(iterable)))
				else:
					raise TypeError('dtype must be provided when it cannot be deduced from the iterable')
			except StopIteration:
				raise ValueError('iterable is empty')
		
		# initialize the internal structure
		self.ptr = NULL
		self.size = 0
		self.allocated = 0
		self.dtype = declared(dtype)
		if not self.dtype:
			raise TypeError('dtype must be a dtype declaration instance, or a key for a declared dtype')
		
		# borrow a buffer
		if PyObject_CheckBuffer(iterable):
			self._use(iterable)
			self.size = self.allocated
			if reserve:
				self._reallocate(reserve * self.dtype.dsize)
		# fill with an iterable
		else:
			if reserve:
				self._reallocate(reserve * self.dtype.dsize)
			if iterable is not None:
				if first is not None:
					self.append(first)
				self.extend(iterable)
				
	@staticmethod
	def full(value, size):
		''' full(value, size)
		
			create a new typedlist with the given `size`, all elements initialized to `value`. 
		'''
		cdef ssize_t i
		cdef typedlist array = typedlist(dtype=type(value), reserve=size)
		for i in range(size):
			array._setitem(array.ptr + i*array.dtype.dsize, value)
		array.size = array.allocated
		return array
		
	@staticmethod
	def empty(dtype, size):
		''' empty(dtype, size)
		
			create a new typedlist with the given `size` and unitialized elements of type `dtype`
		'''
		cdef typedlist array = typedlist(dtype=dtype, reserve=size)
		array.size = array.allocated
		return array
	
	# convenient internal functions
	
	cdef object _getitem(self, void* place):
		return <object> self.dtype.c_unpack(<PyObject*>self.dtype, <PyObject*> place)
		
	cdef int _setitem(self, void* place, obj) except -1:
		return self.dtype.c_pack(<PyObject*>self.dtype, place, <PyObject*> obj)
	
	cdef int _use(self, buffer) except -1:
		cdef Py_buffer view
		
		assign_buffer_obj(&view, None)
		PyObject_GetBuffer(buffer, &view, PyBUF_SIMPLE)
		self.ptr = view.buf
		self.allocated = view.len
		self.owner = buffer
		PyBuffer_Release(&view)
		
	cdef int _reallocate(self, size_t size) except -1:
		lastowner = self.owner
		lastptr = self.ptr
		
		#self._use(bytes(size))		# buffer protocol is less efficient than PyBytes_AS_STRING
		self.owner = bytes(size)
		self.ptr = PyBytes_AS_STRING(self.owner)
		self.allocated = size
		
		self.size = min(size, self.size)
		memcpy(self.ptr, lastptr, self.size)
		
	cdef size_t _len(self):
		return self.size // self.dtype.dsize
		
	cdef Py_ssize_t _index(self, index) except -1:
		''' return a C index (0 < i < l) from a python object '''
		cdef Py_ssize_t i = index
		cdef Py_ssize_t l = self._len()
		if i < 0:	i += l
		if i < 0 or i >= l:	
			raise IndexError('index out of range')
		return i
	
	# python interface
	
	def reserve(self, amount):
		''' reserve(amount: int)
		
			Make sure there is enough allocated memory to append the given amount of elements. 
		
			if there is not enough of allocated memory, the memory is reallocated immediately.
		'''
		if amount < 0:	
			raise ValueError('amount must be positive')
		cdef size_t asked = self.size + (<size_t>amount) * self.dtype.dsize
		if asked > self.allocated:
			self._reallocate(asked)
	
	cpdef void append(self, value):
		''' append the given object at the end of the array
		
			if there is not enough allocated memory, reallocate enough to amortize the realocation time over the multiple appends
		'''
		value = into(value, self.dtype)
		
		if self.allocated - self.size < self.dtype.dsize:
			self._reallocate(self.allocated*2 or self.dtype.dsize)
		
		self._setitem(self.ptr + self.size, value)
		self.size += self.dtype.dsize
		
	def pop(self, index=None):
		''' remove the element at index, returning it. If no index is specified, it will pop the last one '''
		cdef size_t i
		i = self._index(index)	if index is not None else  self._len()
		
		cdef void * start = self.ptr + i*self.dtype.dsize
		e = self._getitem(start)
		memmove(start, start + self.dtype.dsize, self.size-(i-1)*self.dtype.dsize)
		self.size -= self.dtype.dsize
		return e
		
	def insert(self, index, value):
		''' insert value at index '''
		value = into(value, self.dtype)
		cdef size_t i = self._index(index)
		
		if self.allocated - self.size < self.dtype.dsize:
			self._reallocate(self.allocated*2 or self.dtype.dsize)
			
		cdef void * start = self.ptr + i*self.dtype.dsize
		memmove(start+self.dtype.dsize, start, self.size-i*self.dtype.dsize)
		self._setitem(start, value)
		self.size += self.dtype.dsize
		
	def clear(self):
		self.size = 0
		
	cpdef int extend(self, other) except *:
		''' append all elements from the other array '''
		cdef Py_buffer view
		cdef Py_ssize_t l
		
		if PyObject_CheckBuffer(other):
			assign_buffer_obj(&view, None)
			PyObject_GetBuffer(other, &view, PyBUF_SIMPLE)
			
			if <size_t>view.len > self.allocated - self.size:
				self._reallocate(max(2*self.size, self.size + view.len))
			memcpy(self.ptr+self.size, view.buf, view.len)
			self.size += view.len
			
			PyBuffer_Release(&view)
			
		else:
			l = PyObject_LengthHint(other, 0)
			if l >= 0 and l*self.dtype.dsize > self.allocated - self.size:
				self._reallocate(max(2*self.size, self.size + l*self.dtype.dsize))
			for o in other:
				self.append(o)
				
	def __iadd__(self, other):
		self.extend(other)
		return self
		
	def __add__(typedlist self, other):
		cdef typedlist result
		cdef Py_buffer view
		
		if PyObject_CheckBuffer(other):
			assign_buffer_obj(&view, None)
			PyObject_GetBuffer(other, &view, PyBUF_SIMPLE)
			
			result = typedlist.__new__(typedlist)
			result.dtype = self.dtype
			result._reallocate(self.size + view.len)
			memcpy(result.ptr, self.ptr, self.size)
			memcpy(result.ptr+self.size, view.buf, view.len)
			result.size = result.allocated
			
			PyBuffer_Release(&view)
			return result
			
		elif hasattr(other, '__iter__'):
			result = typedlist(None, self.dtype)
			result.extend(self)
			result.extend(other)
			return result
			
		else:
			return NotImplemented
			
	def __mul__(self, n):
		#if isinstance(n, int):
		if PyNumber_Check(<PyObject*>n):
			return typedlist(bytes(self)*n, dtype=self.dtype)
		else:
			return NotImplemented
	
	def capacity(self):
		''' capacity()
		
			return the total number of elements that can be stored with the current allocated memory 
		'''
		return self.allocated // self.dtype.dsize
		
	def shrink(self):
		''' shrink()
		
			reallocate the array to have allocated the exact current size of the array 
		'''
		self._reallocate(self.size)
		
	def __len__(self):
		''' return the current amount of elements inserted '''
		return self._len()
		
	def __getitem__(self, index):
		cdef typedlist view
		cdef Py_ssize_t start, stop, step
		
		#if isinstance(index, int):
		if PyNumber_Check(<PyObject*>index):
			return self._getitem(self.ptr + self._index(index)*self.dtype.dsize)
		
		elif isinstance(index, slice):
			if PySlice_Unpack(index, &start, &stop, &step):
				raise IndexError('incorrect slice')
			if step != 1:
				raise IndexError('slice step is not supported')
			PySlice_AdjustIndices(self._len(), &start, &stop, step)
			
			view = typedlist.__new__(typedlist)
			view.ptr = self.ptr + start*self.dtype.dsize
			view.size = (stop-start)*self.dtype.dsize
			view.allocated = view.size
			view.owner = self.owner
			view.dtype = self.dtype
			return view
		
		else:
			raise IndexError('index must be int or slice')
			
	def __setitem__(self, index, value):
		cdef Py_buffer view
		cdef Py_ssize_t start, stop, step
		
		#if isinstance(index, int):
		if PyNumber_Check(<PyObject*>index):
			value = into(value, self.dtype)
			self._setitem(self.ptr + self._index(index)*self.dtype.dsize, value)
			
		elif isinstance(index, slice):
			if PySlice_Unpack(index, &start, &stop, &step):
				raise IndexError('incorrect slice')
			if step != 1:
				raise IndexError('slice step is not supported')
			PySlice_AdjustIndices(self._len(), &start, &stop, step)
			
			if PyObject_CheckBuffer(value):
				assign_buffer_obj(&view, None)
				PyObject_GetBuffer(value, &view, PyBUF_SIMPLE)
				start *= self.dtype.dsize
				stop *= self.dtype.dsize
				
				if view.len != stop-start:
					if view.len % self.dtype.dsize:
						PyBuffer_Release(&view)
						raise TypeError('the given buffer must have a size multiple of dtype size')
					if view.len - (stop-start) >  (<ssize_t> self.allocated):
						self._reallocate(self.size+view.len)
					memmove(self.ptr+view.len, self.ptr+stop, self.size-stop)
				
				memcpy(self.ptr+start, view.buf, view.len)
				
				PyBuffer_Release(&view)
				
			elif hasattr(value, '__iter__'):
				self[index] = typedlist(value, self.dtype)
				
			else:
				raise IndexError('the assigned value must be a buffer or an iterable')
			
		else:
			raise IndexError('index must be int')
			
	def __iter__(self):
		cdef arrayiter it = arrayiter.__new__(arrayiter)
		it.array = self
		it.position = 0
		return it
		
	def __repr__(self):
		cdef size_t i
		text = 'typedlist(['
		for i in range(self._len()):
			if i:	text += ', '
			text += repr(self._getitem(self.ptr + i*self.dtype.dsize))
		text += '])'
		return text
		
	def __eq__(self, other):
		''' return True if other is a typedlist and its buffer byte contents is the same '''
		if not isinstance(other, typedlist):	return False
		cdef typedlist o = other
		if self.size != o.size:		return False
		return 0 == memcmp(self.ptr, o.ptr, self.size)
		
	def __copy__(self):
		''' shallow copy will create a copy of that array referencing the same buffer '''
		return self[:]
		
	def __deepcopy__(self, memo):
		''' deep recursive copy,  will duplicate the underlying buffer '''
		cdef typedlist new = typedlist(bytes(self.owner), self.dtype)
		new.ptr = self.ptr
		new.size = self.size
		return new
		
	def __reduce_ex__(self, protocol):
		''' serialization protocol '''
		cdef Py_buffer view
			
		if protocol >= 5:
			assign_buffer_obj(&view, None)
			PyObject_GetBuffer(self.owner, &view, PyBUF_SIMPLE)
			return self._rebuild, (
						PickleBuffer(self.owner), 
						self.dtype, 
						self.ptr-view.buf, 
						self.size,
						), 	None
		else:
			return self._rebuild, (
						PyBytes_FromStringAndSize(<char*>self.ptr, self.size), 
						self.dtype,
						0, 
						self.size,
						)
	
	@classmethod
	def _rebuild(cls, owner, dtype, size_t start, size_t size):
		new = typedlist(owner, dtype)
		assert start <= size
		assert size <= new.size
		new.ptr = new.ptr + start
		new.size = size
		return new
		
	def __getbuffer__(self, Py_buffer *view, int flags):
		cdef arrayexposer exp = arrayexposer.__new__(arrayexposer)
		exp.owner = self.owner
		exp.shape[0] = self._len()
	
		view.obj = exp
		view.buf = self.ptr
		view.len = self.size
		view.ndim = 1
		
		if flags & PyBUF_FORMAT:
			fmt = self.dtype.layout
			if fmt is not None:
				view.itemsize = self.dtype.dsize
				view.format = PyBytes_AS_STRING(fmt)
			else:
				view.itemsize = 1
				view.format = 'B'
		else:
			view.itemsize = 1
			view.format = NULL
		
		if flags & PyBUF_ND:
			view.suboffsets = NULL
			view.strides = &view.itemsize
			view.shape = exp.shape
		else:
			view.shape = NULL
			
		
	def __releasebuffer__(self, Py_buffer *view):
		pass
		
	def reverse(self):
		''' reverse the order of elementd contained '''
		cdef void *temp
		cdef void *first
		cdef void *last
		cdef size_t i
		
		temp = PyMem_Malloc(self.dtype.dsize)
		first = self.ptr
		last = self.ptr + self.size - self.dtype.dsize
		while first != last:
			memcpy(temp, first, self.dtype.dsize)
			memcpy(first, last, self.dtype.dsize)
			memcpy(last, temp, self.dtype.dsize)
			first += self.dtype.dsize
			last -= self.dtype.dsize
		PyMem_Free(temp)
		
	def index(self, value):
		''' return the index of the first element binarily equal to the given one '''
		# TODO: decide whether it is acceptable or not, to assume that elements are equals <=> their byte representation is
		cdef size_t i, j
		cdef char *data
		cdef char *val
		value = into(value, self.dtype)
			
		data = <char*> self.ptr
		val = <char*> PyMem_Malloc(self.dtype.dsize)
		self._setitem(val, value)
		
		i = 0
		while i < self.size:
			j = 0
			while data[i+j] == val[j] and j < self.dtype.dsize:
				j += 1
			if j == self.dtype.dsize:
				return i//self.dtype.dsize
			i += self.dtype.dsize
				
		raise IndexError('value not found')
			
			
			
cdef class arrayexposer:
	''' very simple object that just holds the data for the buffer objects '''
	cdef readonly object owner
	cdef Py_ssize_t shape[1]



cdef class arrayiter:
	cdef typedlist array
	cdef size_t position
	
	def __init__(self):
		raise TypeError('arrayiter must not be instanciated explicitely')
	
	def __iter__(self):
		return self
		
	def __next__(self):
		if self.position == self.array.size:
			raise StopIteration()
		item = self.array._getitem(self.array.ptr + self.position)
		self.position += self.array.dtype.dsize
		return item
