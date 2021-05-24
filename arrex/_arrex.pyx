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




# dictionnary of compatible packed types
cdef dict _declared = {}	# {type: (format, dsize, converter)}


cpdef into(obj, target):
	''' convert an object into the target type, using the declared constructor '''
	if type(obj) is target:		return obj
	
	converter = _declared[target][0]
	if converter is None:	
		raise TypeError('cannot implicitely convert {} into {}'.format(
								type(obj).__name__, 
								target.__name__,
								))
	return converter(obj)
	
cpdef declare(dtype, constructor=None, format=None):
	''' declaire(dtype, constructor=None, format=None)
	
		declare a new dtype 
	
		:constructor:	
		
			A callable used to convert objects into dtype (eg for append to an array).
			The constructor will allow to insert any kind of input object the constructor does support and convert into the proper type
			
			leave it to None to disallow implicit conversions
			
			Note that the constructor MUST return an instance of the dtype, or bad things will happen
		
		:format:		
		
			The internal format of the dtype as describes in the `struct` module.
			
			if the given format is too small for the dtype size, padding bytes will be added at the beginning of it
			
			leave it to None if you don't need to convert arrays of that dtype into numpy arrays
	'''
	if not isinstance(dtype, type):
		raise TypeError('dtype must be a type')
	if constructor is not None and not callable(constructor):
		raise TypeError('constructor must be a callable returning an instance of dtype')
		
	packsize = (<PyTypeObject*> dtype).tp_basicsize - sizeof(_head)
	if format is not None:
		if isinstance(format, str):
			format = format.encode()
		elif not isinstance(format, bytes):
			format = bytes(format)
		
		fmtsize = struct.calcsize(format)
		if packsize < fmtsize:
			raise ValueError('format describes a too big structure for the given dtype')
	else:
		fmtsize = 0
	
	dsize = fmtsize or packsize
	if not dsize:
		raise TypeError('dsize cannot be 0')
	
	_declared[dtype] = (constructor, format, dsize)
	
def declared(dtype):
	''' return the content of the declaration for the givne dtype, if not declared it will return None '''
	return _declared.get(dtype)

	

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
	
	cdef readonly type dtype
	cdef readonly size_t dsize
	
	cdef readonly object owner
	

	def __init__(self, iterable=None, type dtype=None, size_t reserve=0):
		# look at the type of the first element
		first = None
		if not dtype:
			try:
				if hasattr(iterable, '__next__'):
					first = next(iterable)
					dtype = type(first)
				elif hasattr(iterable, '__iter__'):
					dtype = type(next(iter(iterable)))
			except StopIteration:
				raise ValueError('iterable is empty, dtype must be specified')
	
		# get the dtype declaration
		cdef tuple decl = _declared.get(dtype)
		if decl is None:
			raise TypeError('dtype must be packed and declared in dict dynarray.declared')
		
		# initialize the internal structure
		self.ptr = NULL
		self.size = 0
		self.allocated = 0
		self.dtype = dtype
		self.dsize = decl[2]
		
		# borrow a buffer
		if PyObject_CheckBuffer(iterable):
			self._use(iterable)
			self.size = self.allocated
			if reserve:
				self._reallocate(reserve * self.dsize)
		# fill with an iterable
		else:
			if reserve:
				self._reallocate(reserve * self.dsize)
			if iterable is not None:
				if first is not None:
					self.append(first)
				self.extend(iterable)
				
	@staticmethod
	def full(value, size):
		''' full(value, size)
		
			create a new typedlist with the given `size`, all elements initialized to `value`. 
		'''
		cdef size_t i
		cdef typedlist array = typedlist(dtype=type(value), reserve=size)
		for i in range(size):
			array._setitem(array.ptr + i*array.dsize, value)
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
	
	cdef int _use(self, buffer) except -1:
		cdef Py_buffer view
		
		assign_buffer_obj(&view, None)
		PyObject_GetBuffer(buffer, &view, PyBUF_SIMPLE)
		self.ptr = view.buf
		self.allocated = view.len
		self.owner = buffer
		PyBuffer_Release(&view)
		return 0
		
	cdef int _reallocate(self, size_t size) except -1:
		lastowner = self.owner
		lastptr = self.ptr
		
		#self._use(bytes(size))		# buffer protocol is less efficient than PyBytes_AS_STRING
		self.owner = bytes(size)
		self.ptr = PyBytes_AS_STRING(self.owner)
		self.allocated = size
		
		memcpy(self.ptr, lastptr, self.size)
		self.size = min(size, self.size)
		return 0
		
	cdef size_t _len(self):
		return self.size // self.dsize
		
	cdef Py_ssize_t _index(self, index) except -1:
		''' return a C index (0 < i < l) from a python object '''
		cdef Py_ssize_t i = index
		cdef Py_ssize_t l = self._len()
		if i < 0:	i += l
		if i < 0 or i >= l:	
			raise IndexError('index out of range')
		return i
		
	cdef object _getitem(self, void *ptr):
		''' build a python object a pointer to the data it must contain '''
		#item = PyType_GenericAlloc(<PyTypeObject*><PyObject*>self.dtype, 0)
		item = (<PyTypeObject*>self.dtype).tp_new(self.dtype, _empty, None)
		memcpy((<void*><PyObject*>item) + (<PyTypeObject*>self.dtype).tp_basicsize - self.dsize, ptr, self.dsize)
		return item
		
	cdef void _setitem(self, void *ptr, value):
		''' dump the object data at the pointer location '''
		memcpy(ptr, (<void*><PyObject*> value) + (<PyTypeObject*>self.dtype).tp_basicsize - self.dsize, self.dsize)
		
	
	# python interface
	
	def reserve(self, amount):
		''' reserve(amount: int)
		
			Make sure there is enough allocated memory to append the given amount of elements. 
		
			if there is not enough of allocated memory, the memory is reallocated immediately.
		'''
		if amount < 0:	
			raise ValueError('amount must be positive')
		cdef size_t asked = self.size + (<size_t>amount) * self.dsize
		if asked > self.allocated:
			self._reallocate(asked)
	
	cpdef void append(self, value):
		''' append the given object at the end of the array
		
			if there is not enough allocated memory, reallocate enough to amortize the realocation time over the multiple appends
		'''
		value = into(value, self.dtype)
		
		if self.allocated - self.size < self.dsize:
			self._reallocate(self.allocated*2 or self.dsize)
		
		self._setitem(self.ptr + self.size, value)
		self.size += self.dsize
		
	def pop(self, index=None):
		''' remove the element at index, returning it. If no index is specified, it will pop the last one '''
		cdef size_t i
		i = self._index(index)	if index is not None else  self._len()
		
		cdef void * start = self.ptr + i*self.dsize
		e = self._getitem(start)
		memmove(start, start + self.dsize, self.size-(i-1)*self.dsize)
		self.size -= self.dsize
		return e
		
	def insert(self, index, value):
		''' insert value at index '''
		value = into(value, self.dtype)
		cdef size_t i = self._index(index)
		
		if self.allocated - self.size < self.dsize:
			self._reallocate(self.allocated*2 or self.dsize)
			
		cdef void * start = self.ptr + i*self.dsize
		memmove(start+self.dsize, start, self.size-i*self.dsize)
		self._setitem(start, value)
		self.size += self.dsize
		
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
			if l >= 0 and l*self.dsize > self.allocated - self.size:
				self._reallocate(max(2*self.size, self.size + l*self.dsize))
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
			result.dsize = self.dsize
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
		if isinstance(n, int):
			return typedlist(bytes(self.owner)*n, dtype=self.dtype)
		else:
			return NotImplemented
	
	def capacity(self):
		''' capacity()
		
			return the total number of elements that can be stored with the current allocated memory 
		'''
		return self.allocated // self.dsize
		
	def shrink(self):
		''' shrink()
		
			reallocate the array to have allocated the exact current size of the array 
		'''
		if self.size == 0:
			if self.hooks:
				raise RuntimeError('cannot free memory while a view is opened on')
			PyMem_Free(self.ptr)
			self.ptr = NULL
			self.allocated = 0
		else:
			self._reallocate(self.size)
		
	def __len__(self):
		''' return the current amount of elements inserted '''
		return self._len()
		
	def __getitem__(self, index):
		cdef typedlist view
		cdef Py_ssize_t start, stop, step
		
		if isinstance(index, int):
			return self._getitem(self.ptr + self._index(index)*self.dsize)
		
		elif isinstance(index, slice):
			if PySlice_Unpack(index, &start, &stop, &step):
				raise IndexError('incorrect slice')
			if step != 1:
				raise IndexError('slice step is not supported')
			PySlice_AdjustIndices(self._len(), &start, &stop, step)
			
			view = typedlist.__new__(typedlist)
			view.ptr = self.ptr + start*self.dsize
			view.size = (stop-start)*self.dsize
			view.allocated = view.size
			view.owner = self.owner
			view.dtype = self.dtype
			view.dsize = self.dsize
			return view
		
		else:
			raise IndexError('index must be int')
			
	def __setitem__(self, index, value):
		if isinstance(index, int):
			value = into(value, self.dtype)
			self._setitem(self.ptr + self._index(index)*self.dsize, value)
			
		else:
			raise IndexError('index must be int')
			
	def __iter__(self):
		cdef arrayiter it = arrayiter.__new__(arrayiter)
		it.array = self
		it.position = 0
		return it
		
	def __repr__(self):
		cdef size_t i
		item = (<PyTypeObject*>self.dtype).tp_new(self.dtype, _empty, None)
		text = 'typedlist(['
		for i in range(self._len()):
			if i:	text += ', '
			memcpy(
					(<void*><PyObject*>item) 
					+ (<PyTypeObject*>self.dtype).tp_basicsize 
					- self.dsize, 
				self.ptr + i*self.dsize, 
				self.dsize)
			text += repr(item)
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
		''' deep recursive copy,  will duplicate the appropriate portion of the underlying buffer '''
		cdef typedlist new = typedlist(dtype=self.dtype)
		new._reallocate(self.size)
		memcpy(new.ptr, self.ptr, self.size)
		new.size = self.size
		return new
		
	def __reduce_ex__(self, protocol):
		''' serialization protocol 
			if `protocol>=5`, data will not be copied if shared accross threads
		'''
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
		''' only for the serialization protocol '''
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
			fmt = _declared[self.dtype][1]
			if fmt is not None:
				view.itemsize = self.dsize
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
		
	"""
	def convert(self, dtype):
		'''
			typedlist(... dtype='f4 xx u2') .convert('f8 u1 x')
		'''
		pass
		
	def cast(self, dtype):
		''' Reuse the same memory, but consider it to be of the new dtype instead.
			The new dtype must be a multiple or a fraction of the current one, the factor will change the array shape
		'''
		pass
		
	def sub(self, key):
		''' Return an array of the components of the currrent dtype at `key` 
		'''
		pass
	"""
			
			
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
		self.position += self.array.dsize
		return item
		
"""
cdef class typedarray:
	cdef void *ptr
	cdef size_t *shape
	cdef size_t *strides
	
	cdef type dtype
	cdef size_t dsize
	
	cdef readonly object owner
	

def merge(*args) -> typedarray:
	''' merge the arrays by merging the dtype.
		requires all the arrays to share the same shape
	'''
	pass
	
def concat(*args, axis=0) -> typedarray:
	''' concatenate the arrays, placing them one after the other.
		requires all the arrays to share the same dtype
	'''
	pass
	
cdef dict _ufuncs = {}	# {(operation, *dtypes): func}
def vect(func) -> callable:
	''' return a callable executing the given function on arrays of its initial arguments 
	
			# use it in expressions
			>>> vect(sin) ([x1, x2, x3])
	
			# use it as a decorator
			>>> @vect
			... def my_function_to_vectorize(...):
			... 	# do something
	'''
	pass
"""
