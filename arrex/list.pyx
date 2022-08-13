# cython: language_level=3, cdivision=True

cimport cython
from cpython cimport PyObject, PyTypeObject, Py_buffer, Py_INCREF, Py_DECREF, Py_XDECREF, PyObject_Length
from cpython.mem cimport PyMem_Malloc, PyMem_Realloc, PyMem_Free
from cpython.buffer cimport PyBUF_SIMPLE, PyBUF_ND, PyBUF_FORMAT, PyObject_CheckBuffer, PyObject_GetBuffer, PyBuffer_Release
from cpython.bytes cimport PyBytes_FromStringAndSize, PyBytes_AsString, PyBytes_AS_STRING
from cpython.slice cimport PySlice_Unpack, PySlice_AdjustIndices
from cpython.number cimport PyNumber_Check
from libc.string cimport memcpy, memmove, memcmp
from libc.stdlib cimport malloc, free

import struct
from pickle import PickleBuffer
import sys

cdef extern from "Python.h":
	Py_ssize_t PyObject_LengthHint(object o, Py_ssize_t default)


from .dtypes cimport *

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
	
cdef extern from *:
	"""
	void release_buffer_obj(Py_buffer* buf) {
		if (buf->obj != NULL)
			Py_DECREF(buf->obj);
	}
	"""
	void release_buffer_obj(Py_buffer* buf)


	
cdef class typedlist:
	''' list-like array that stores objects as packed data. 
		The objects added must necessarily be packed objects (builtin objects with no references).
		
		This is a dynamically sized, borrowing array, which mean the internal buffer of data is reallocated on insertion, but can be used to view and extract from any buffer.
		
		Methods added to the signature of list:
		
			`reserve(n)`            reallocate if necessary to make sure n elements can 
			                        be inserted without reallocation
			`capacity() -> int`     return the current number of elements that can be 
			                        contained without reallocation
			`shrink()`              shorten the allocated memory to fit the current content
			
			also the slices do not copy the content
		
		
		Use it as a list:
		
			>>> a = typedlist(dtype=vec3)
			>>> 
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
			>>> 
			>>> a.owner	# the current data buffer
			b'.........'
			
		Use it as a slice:
		
			>>> # no data is copied
			>>> myslice = a[:5]
			typedlist(....)
			
		Use it as a view on top of a random buffer
		
			>>> a = np.ones((6,3), dtype='f4')
			>>> myslice = typedlist(a, dtype=vec3)
			
		It does support the buffer protocol, so it can be converted in a great variety of well known arrays, even without any copy
		
			>>> np.array(typedlist([....]))
		
		
		Constructors:
			
			.. py:function:: typedlist()
			.. py:function:: typedlist(dtype, reserve=None)
			.. py:function:: typedlist(iterable, dtype, reserve=None)
			.. py:function:: typedlist(buffer, dtype)
			
		Attributes:
			
			size (int):        byte size of the current content
			allocated (int):   byte size of the memory allocated memory
			owner:             object realy owning the data instead of the current `typedlist`
			
			dtype (type):         the python data type
			ddtype (DDType):      the data type declaration
	'''

	cdef char *ptr
	cdef readonly size_t size
	cdef readonly size_t allocated
	
	cdef DDType dtype
	
	cdef readonly object owner
	
	@property
	def dtype(self):
		''' the python dtype object, or the ddtype if there is not dtype '''
		return self.dtype.key or self.dtype
		
	@property
	def ddtype(self):
		''' the declaration of the dtype, a DDType instance '''
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
		self.owner = None
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
	def full(value, size, dtype=None):
		''' full(value, size)
		
			create a new typedlist with the given `size`, all elements initialized to `value`. 
		'''
		cdef ssize_t i
		cdef typedlist array = typedlist(dtype=dtype or type(value), reserve=size)
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
		return self.dtype.c_unpack(self.dtype, place)
		
	cdef int _setitem(self, void* place, obj) except -1:
		return self.dtype.c_pack(self.dtype, place, obj)
	
	cdef int _use(self, buffer) except -1:
		cdef Py_buffer view
		
		PyObject_GetBuffer(buffer, &view, PyBUF_SIMPLE)
		self.ptr = <char*> view.buf
		self.allocated = view.len
		self.owner = view.obj
		PyBuffer_Release(&view)
		
	cdef int _reallocate(self, size_t size) except -1:
		lastowner = self.owner
		lastptr = self.ptr
		
		# buffer protocol is less efficient that PyBytes_AS_STRING so we use it directly here where we know that owner is bytes
		self.owner = PyBytes_FromStringAndSize(NULL, size)
		self.ptr = PyBytes_AS_STRING(self.owner)
		#cdef buffer buff = buffer(size)
		#self.owner = buff
		#self.ptr = buff.ptr
		
		#print('** reallocate', sys.getrefcount(self.owner), sys.getrefcount(lastowner), lastowner is None)
		
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
	
	cpdef int append(self, value) except -1:
		''' append(value)
		
			append the given object at the end of the array
		
			if there is not enough allocated memory, reallocate enough to amortize the realocation time over the multiple appends
		'''		
		if self.allocated < self.size + self.dtype.dsize:
			self._reallocate(self.allocated*2 or self.dtype.dsize)
		
		self._setitem(self.ptr + self.size, value)
		self.size += self.dtype.dsize
		
	def pop(self, index=None):
		''' pop(index=None) -> object
		
			remove the element at index, returning it. If no index is specified, it will pop the last one .
		'''
		cdef size_t i
		cdef char * start
		
		if not self.size:
			raise IndexError('pop from empty list')
		
		if index is None:
			e = self._getitem(self.ptr + self.size - self.dtype.dsize)
			self.size -= self.dtype.dsize
			return e
		else:
			i = self._index(index)
			
			start = self.ptr + i*self.dtype.dsize
			e = self._getitem(start)
			memmove(start, start + self.dtype.dsize, self.size-(i+1)*self.dtype.dsize)
			self.size -= self.dtype.dsize
			return e
		
	def insert(self, index, value):
		''' insert(index, value)
		
			insert value at index 
		'''
		
		cdef Py_ssize_t i = index
		cdef Py_ssize_t l = self._len()
		if i < 0:	i += l
		if i < 0 or i > l:	
			raise IndexError('index out of range')
		cdef size_t j = i
		
		if self.allocated - self.size < self.dtype.dsize:
			self._reallocate(self.allocated*2 or self.dtype.dsize)
			
		cdef char * start = self.ptr + j*self.dtype.dsize
		memmove(start+self.dtype.dsize, start, self.size-j*self.dtype.dsize)
		self._setitem(start, value)
		self.size += self.dtype.dsize
		
	def clear(self):
		''' remove all elements from the array but does not deallocate, very fast operation '''
		self.size = 0
		
	cpdef int extend(self, other) except *:
		''' extend(iterable)
		
			append all elements from the other array 
		'''
		cdef Py_buffer view
		cdef Py_ssize_t l
		
		if PyObject_CheckBuffer(other):
			PyObject_GetBuffer(other, &view, PyBUF_SIMPLE)
			
			if view.len % self.dtype.dsize:
				PyBuffer_Release(&view)
				raise TypeError('the given buffer must have a byte size multiple of dtype size')
			
			if <size_t>view.len > self.allocated - self.size:
				self._reallocate(max(2*self.size, self.size + view.len))
			memcpy(self.ptr+self.size, view.buf, view.len)
			self.size += view.len
			
			PyBuffer_Release(&view)
			
		else:
			l = PyObject_LengthHint(other, 0)
			if l*self.dtype.dsize > self.allocated - self.size:
				self._reallocate(self.size + l*self.dtype.dsize)
			for o in other:
				self.append(o)
				
	def __iadd__(self, other):
		self.extend(other)
		return self
		
	def __add__(typedlist self, other):
		''' concatenation of two arrays '''
		cdef typedlist result
		cdef Py_buffer view
		
		if PyObject_CheckBuffer(other):
			PyObject_GetBuffer(other, &view, PyBUF_SIMPLE)
			
			if view.len % self.dtype.dsize:
				PyBuffer_Release(&view)
				raise TypeError('the given buffer must have a byte size multiple of dtype size')
			
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
		''' duplicate the sequence by a certain number '''
		#if isinstance(n, int):
		if PyNumber_Check(n):
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
		''' self[index]
		
			currently supports:
			
				- indices
				- negative indices
				- slices with step=1
		'''
		cdef typedlist view
		cdef Py_ssize_t start, stop, step
		
		#if isinstance(index, int):
		if PyNumber_Check(index):
			return self._getitem(self.ptr + self._index(index)*self.dtype.dsize)
		
		elif isinstance(index, slice):
			if PySlice_Unpack(index, &start, &stop, &step):
				raise IndexError('incorrect slice')
			if step != 1:
				raise IndexError('slice step is not supported')
			PySlice_AdjustIndices(self._len(), &start, &stop, step)
			if stop < start:
				stop = start
			
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
		cdef size_t newsize
		
		#if isinstance(index, int):
		if PyNumber_Check(index):
			self._setitem(self.ptr + self._index(index)*self.dtype.dsize, value)
			
		elif isinstance(index, slice):
			if PySlice_Unpack(index, &start, &stop, &step):
				raise IndexError('incorrect slice')
			if step != 1:
				raise IndexError('slice step is not supported')
			PySlice_AdjustIndices(self._len(), &start, &stop, step)
			if stop < start:
				stop = start
			
			if PyObject_CheckBuffer(value):
				PyObject_GetBuffer(value, &view, PyBUF_SIMPLE)
				start *= self.dtype.dsize
				stop *= self.dtype.dsize
				
				if view.len != stop-start:
					if view.len % self.dtype.dsize:
						PyBuffer_Release(&view)
						raise TypeError('the given buffer must have a byte size multiple of dtype size')
					
					newsize = self.size + view.len + start - stop
					if newsize >  self.allocated:
						self._reallocate(max(2*self.size, newsize))
					
					memmove(self.ptr+start+view.len, self.ptr+stop, self.size-stop)
					self.size = newsize
				
				memcpy(self.ptr+start, view.buf, view.len)
				
				PyBuffer_Release(&view)
				
			elif hasattr(value, '__iter__'):
				self[index] = typedlist(value, self.dtype)
				
			else:
				raise IndexError('the assigned value must be a buffer or an iterable')
			
		else:
			raise IndexError('index must be int or slice')
			
	def __delitem__(self, index):
		cdef Py_ssize_t start, stop, step
		
		if PyNumber_Check(index):
			start = index
			stop = index+1
		elif isinstance(index, slice):
			if PySlice_Unpack(index, &start, &stop, &step):
				raise IndexError('incorrect slice')
			if step != 1:
				raise IndexError('slice step is not supported')
			PySlice_AdjustIndices(self._len(), &start, &stop, step)
		else:
			raise IndexError('index must be int or slice')
			
		start *= self.dtype.dsize
		stop *= self.dtype.dsize
		memmove(self.ptr+start, self.ptr+stop, self.size-stop)
		self.size = self.size + start - stop

			
	def __iter__(self):
		''' yield successive elements in the list '''
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
		''' deep recursive copy,  will duplicate the viewed data in the underlying buffer '''
		return typedlist(PyBytes_FromStringAndSize(<char*>self.ptr, self.size), self.dtype)
		
	def __reduce_ex__(self, protocol):
		''' serialization protocol '''
		cdef Py_buffer view
		
		if protocol >= 5:
			if not PyObject_CheckBuffer(self.owner):
				raise RuntimeError("the buffer owner doens't implement the buffer protocol")
			PyObject_GetBuffer(self.owner, &view, PyBUF_SIMPLE)
			stuff = (
						PickleBuffer(self.owner), 
						self.dtype, 
						self.ptr - <char*>view.buf, 
						self.size,
						)
			PyBuffer_Release(&view)
			return self._rebuild, stuff, None
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
	
		assign_buffer_obj(view, None)
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
		cdef arrayexposer exp = view.obj
		print('** release buffer', sys.getrefcount(exp.owner))
		exp.owner = None
		view.obj = None
		
	def reverse(self):
		''' reverse()
		
			reverse the order of elementd contained 
		'''
		cdef char *temp
		cdef char *first
		cdef char *last
		cdef size_t i
		
		temp = <char*> PyMem_Malloc(self.dtype.dsize)
		first = self.ptr
		last = self.ptr + self.size - self.dtype.dsize
		while <size_t>first < <size_t>last:
			memcpy(temp, first, self.dtype.dsize)
			memcpy(first, last, self.dtype.dsize)
			memcpy(last, temp, self.dtype.dsize)
			first += self.dtype.dsize
			last -= self.dtype.dsize
		PyMem_Free(temp)
		
	def index(self, value):
		''' index(value)
		
			return the index of the first element binarily equal to the given one 
		'''
		cdef size_t i, j
		cdef char *data
		cdef char *val
			
		data = <char*> self.ptr
		val = <char*> PyMem_Malloc(self.dtype.dsize)
		self._setitem(val, value)
		
		i = 0
		while i < self.size:
			j = 0
			while data[i+j] == val[j] and j < self.dtype.dsize:
				j += 1
			if j == self.dtype.dsize:
				PyMem_Free(val)
				return i//self.dtype.dsize
			i += self.dtype.dsize
			
		PyMem_Free(val)
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
		if self.position + self.array.dtype.dsize > self.array.size:
			raise StopIteration
		item = self.array._getitem(self.array.ptr + self.position)
		self.position += self.array.dtype.dsize
		return item

		
		

'''	
# this is in reserve for debug purpose
# helps to keep track of buffers

cdef size_t buffer_id = 0
cdef size_t buffer_count = 0

cdef class buffer:
	cdef void* ptr
	cdef readonly size_t size
	cdef size_t id
	
	def __cinit__(self, size_t size):
		global buffer_id, buffer_count
		self.id = buffer_id
		buffer_id += 1
		buffer_count += 1
		print('allocate', self.id, size)
		
		self.ptr = PyMem_Malloc(size)
		self.size = size
		
	def __dealloc__(self):
		global buffer_id, buffer_count
		buffer_count -= 1
		PyMem_Free(self.ptr)
		self.ptr = NULL
		print('deallocate', self.id, buffer_count)
		
	def __len__(self):
		return self.size
'''
