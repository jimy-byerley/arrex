# cython: language_level=3, cdivision=True

'''
	The *dtype* is the type of the elements in a buffer. Thanks to the ddtype system, it is very easy to create new dtypes on top of pretty much everything.
	
	Definitions:
	
		:type:    a python type object (typically a class or a builtin type)
		:dtype:   data dtype, meaning the type of the elements in an array,  it can be a type, but more generally anything that define a data format.
		:ddtype:  declaration of data type, meaning a packet of things decribing how to pack/unpack that dtype from/to an array
		
	a ddtype always inherits from base class `DDType` which content is implemented at C level.
'''

cimport cython
from cpython cimport PyObject, PyTypeObject
from libc.string cimport memcpy

import struct, ctypes

cdef extern from "Python.h":
	object PyBytes_FromStringAndSize(const char *v, Py_ssize_t len)
	object PyByteArray_FromStringAndSize(const char *v, Py_ssize_t len)
	char *PyBytes_AsString(object)


	

cdef class DDType:
	''' base class for a declaration of data type (ddtype)
		DO NOT INSTANTIATE THIS CLASS FROM PYTHON, use on of its specialization instead 
		
		Attributes:
		
			dsize (int):     byte size of the dtype when packed
			layout (bytes):  layout of the packed data such as defined in module `struct`, or `None` if not defined
			key:             the python dtype itself if this DDType is declared, `None` if not declared
	'''
	
	def __repr__(self):
		if isinstance(self.key, type):
			return '<dtype {}>'.format(self.key.__name__)
		elif isinstance(self.key, str):
			return '<dtype {}>'.format(repr(self.key))
		else:
			return '<dtype at {}>'.format(id(self))
			
	def __reduce_ex__(self, protocol):
		''' allow serialization of the dtype with the array (particularly useful for anonymous dtypes) '''
		if self.key is None:
			raise TypeError('a dtype must be declared in order to be pickleable')
		return self._rebuild, (self.key, self.dsize, self.layout)
		
	@classmethod
	def _rebuild(cls, key, size_t dsize, bytes layout):
		candidate = declared(key)
		if dsize != candidate.dsize:
			raise ValueError('the pickled dtype {} has a different size here than in dump, unpickled {} expected {}'
						.format(repr(key), dsize, candidate.dsize))
		if candidate.layout and layout != candidate.layout:
			raise ValueError('the pickled dtype {} has a different memory layout here than in dump, unpickled {} expected {}'
						.format(repr(key), layout, candidate.layout))
		return candidate
	

def DDTypeClass(type):
	''' DDTypeClass(type)
	
		Create a dtype from a python class (can be a pure python class) 
		
		the given type must have the following attributes:
		
			- `frombytes` or `from_bytes` or `from_buffer`
			
				static method that initialize the type from bytes
				
			- `__bytes__` or `tobytes` or `to_bytes`
				
				method that converts to bytes, the returned byte must always be of the same size
			
			- `__packlayout__`     (optional)  string or bytes giving binary format returned by `__bytes__`, it must follow the specifications of module `struct`
			- `__packsize__`       (optional)  defines the byte size returned by `__bytes__`, optional if `__packlayout__` is provided
			
		Example:
		
			>>> class test_class:
			... 	__packlayout__ = 'ff'
			... 	_struct = struct.Struct(__packlayout__)
			... 	
			... 	def __init__(self, x, y):
			... 		self.x = x
			... 		self.y = y
			... 	
			... 	def __bytes__(self):
			... 		return self._struct.pack(self.x, self.y)
			... 	@classmethod
			... 	def frombytes(cls, b):
			... 		return cls(*cls._struct.unpack(b))
			... 		
			... 	def __repr__(self):
			... 		return '(x={}, y={})'.format(self.x, self.y)
			... 
			>>> a = typedlist(dtype=test_class)    # no declaration needed
	'''
	layout = getattr(type, '__packlayout__', None)
	dsize = getattr(type, '__packsize__', None)
	if not dsize:
		dsize = struct.calcsize(layout or b'')
	if not dsize:
		raise ValueError('dsize must not be null, __packlayout__ or __packsize__ must be correctly defined in the given type')
	
	pack = getattr(type, '__bytes__', None) or getattr(type, 'tobytes', None) or getattr(type, 'to_bytes', None)
	if not pack:
		raise TypeError("the given type must have a method '__bytes__', 'tobytes', or 'to_bytes'")
	
	unpack = getattr(type, 'frombytes', None) or getattr(type, 'from_bytes', None) or getattr(type, 'from_buffer', None)
	if not unpack:
		raise TypeError("the given type must have a method 'frombytes', 'from_bytes', or 'from_buffer'")
	
	return DDTypeFunctions(dsize, pack, unpack, layout)
	
def DDTypeStruct(definition):
	''' DDTypeStruct(struct)
	
		create a dtype from a Struct object from module `struct` 
	
		Example:
			
			>>> a = typedlist(dtype='fxBh')   # no declaration needed
	'''
	if not isinstance(definition, struct.Struct):
		raise TypeError('structure must be struct.Struct')
	return DDTypeFunctions(definition.size, lambda o: definition.pack(*o), definition.unpack, definition.format) 

cdef class DDTypeFunctions(DDType):
	''' DDTypeFunctions(dsize, pack, unpack, layout=None)
	
		create a dtype from pure python pack and unpack functions 
	
		Example:
		
			>>> enum_pack = {'apple':b'a', 'orange':b'o', 'cake':b'c'}
			>>> enum_unpack = {v:k   for k,v in enum_direct.items()}
			>>> enum_dtype = DDTypeFunctions(
			... 			dsize=1,                         # 1 byte storage
			... 			pack=enum_pack.__getitem__,      # this takes the python object and gives a bytes to dump
			... 			unpack=enum_unpack.__getitem__,  # this takes the bytes and return a python object
			... 			)
			... 
			>>> a = typedlist(dtype=enum_dtype)		# declaration is not necessary
	'''
	cdef public object pack
	cdef public object unpack
	
	def __init__(self, dsize, pack, unpack, layout=None):
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
		elif not dsize:
			raise ValueError('dsize must be provided or deduced from a given layout')
			
		self.dsize = dsize
		self.c_pack = <c_pack_t> self._func_pack
		self.c_unpack = <c_unpack_t> self._func_unpack
		self.layout = layout
		self.pack = pack
		self.unpack = unpack
		
	cdef int _func_pack(self, void* place, object obj) except -1:
		packed = self.pack(obj)
		if not isinstance(packed, bytes):
			raise TypeError('pack must provide a bytes object')
		if len(packed) < <ssize_t> self.dsize:
			raise ValueError('the dumped bytes length {} does not match dsize {}'.format(len(packed), self.dtype.dsize))
		
		memcpy(place, PyBytes_AsString(packed), self.dsize)
	
	cdef object _func_unpack(self, void* place):
		return self.unpack(PyBytes_FromStringAndSize(<char*>place, self.dsize))
		
		
	def __reduce_ex__(self, protocol):
		''' allow serialization of the dtype with the array (particularly useful for anonymous dtypes) '''
		return type(self), (self.dsize, self.pack, self.unpack, self.layout, self.constructor)
		
cdef class DDTypeCType(DDType):
	''' DDTypeCType(type)
	
		Create a dtype from a ctype 
	
		Example:
		
			>>> class test_structure(ctypes.Structure):
			... 	_fields_ = [
			... 		('x', ctypes.c_int),
			... 		('y', ctypes.c_float),
			... 		]
			... 	def __repr__(self):
			... 		return '(x={}, y={})'.format(self.x, self.y)
			... 
			>>> a = typedlist(dtype=test_structure)
	'''
	cdef public object type
	
	def __init__(self, type):
		if not isctype(type):
			raise TypeError('type must be a ctype')
		self.type = type
		self.dsize = ctypes.sizeof(type)
		self.c_pack = <c_pack_t> self._ctype_pack
		self.c_unpack = <c_unpack_t> self._ctype_unpack
		self.layout = None
		
	cdef int _ctype_pack(self, void* place, object obj) except -1:
		if not isinstance(obj, self.type):
			raise TypeError('cannot store an object of a different type')
		memcpy(place, <void*><size_t> ctypes.addressof(obj), self.dsize)
		
	cdef object _ctype_unpack(self, void* place):
		return self.type.from_buffer(PyByteArray_FromStringAndSize(<char*> place, self.dsize))
		
		
cdef class DDTypeExtension(DDType):
	''' DDTypeTypeExtension(type, layout=None, constructor=None)
	
		Create a dtype for a C extension type.
	
		This is the most efficient kind of dtype in term of access/assignation time.
		
		In order to put an extension object into an array, it satisfy the following conditions:
		
		- have fixed size known at the time of dtype creation (so any array element has the same)
		- contain only byte copiable data (so nothing particular is done when copying/destroying the objects)
		
		WARNING:  
		
			These conditions MUST be ensured by the user when declaring an extension type as a dtype, or it will result in memory corruption and crash of the program
		
		
		Example:
		
			>>> arrex.declare(vec3, DDTypeExtension(vec3, 'fff', vec3))
	'''
	cdef public type type
	cdef public object constructor
	
	def __init__(self, type ext, layout=None, constructor=None):
		cdef ssize_t fmtsize, packsize
	
		if not isinstance(ext, type):
			raise TypeError('dtype must be a type')
			
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
		self.type = ext
		self.constructor = constructor
		
	cdef void * _raw(self, obj):
		return (<char*><PyObject*> obj) + (<PyTypeObject*>self.type).tp_basicsize - self.dsize
	
	cdef int _ext_pack(self, void* place, object obj) except -1:
		if not isinstance(obj, self.type):
			if self.constructor is not None:
				obj = self.constructor(obj)
			else:
				raise TypeError('cannot implicitely convert {} into {}'.format(
										type(obj).__name__, 
										repr(self),
										))
		memcpy(place, self._raw(obj), self.dsize)
		
	cdef object _ext_unpack(self, void* place):
		new = (<PyTypeObject*>self.type).tp_new(self.type, _empty, None)
		memcpy(self._raw(new), place, self.dsize)
		return new
	
	def __reduce_ex__(self, protocol):
		''' that overload allows for automatic declaration of the dtype fron the pickled informations, as long as they are consistent with the given type size '''
		return self._rebuild, (self.type, self.dsize, self.layout, self.constructor)
		
	@classmethod
	def _rebuild(cls, type, size_t dsize, bytes layout, constructor):
		candidate = _declared.get(type) or declare(type, DDTypeExtension(type, layout, constructor))
		if dsize != candidate.dsize:
			raise ValueError('the pickled dtype {} has a different size here than in dump, unpickled {} expected {}'
						.format(repr(type), dsize, candidate.dsize))
		if candidate.layout and layout != candidate.layout:
			raise ValueError('the pickled dtype {} has a different memory layout here than in dump, unpickled {} expected {}'
						.format(repr(type), layout, candidate.layout))
		return candidate

		
		

# dictionnary of compatible packed types
cdef dict _declared = {}	# {python type: dtype}
	
cpdef DDType declare(key, DDType dtype=None):
	''' declare(dtype, ddtype)
	
		declare a new dtype 
	'''
	if not dtype:
		if isinstance(key, str):
			# create a struct dtype
			dtype = DDTypeStruct(struct.Struct(key))
		elif isctype(key):
			# create a ctype dtype
			dtype = DDTypeCType(key)
		elif isinstance(key, type):
			# create a dtype from a pure python class
			try:	dtype = DDTypeClass(key)
			except TypeError:	pass
		if not dtype:
			raise TypeError('dtype {} is not declared, and cannot be guessed'.format(key))
	if not dtype.key:
		dtype.key = key
	_declared[key] = dtype
	return dtype
	
cpdef DDType declared(key):
	''' declared(key)
		
		return the content of the declaration for the givne dtype 
	'''
	if isinstance(key, DDType):
		return key
	else:
		# try an automated declaration
		dtype = _declared.get(key) or declare(key)
		# raise an error when not declared
		#raise TypeError('dtype {} is not declared'.format(key))
		return <DDType> dtype

cdef isctype(obj):
	''' isctype(obj)
	
		return True if obj is a ctype type or one of its derivatives, and False otherwise 
	'''
	# there is currently no other way to check this than to try a ctype-only function and detect errors
	# this is an ungly way but better would require changes in ctypes ...
	if not isinstance(obj, type):	return False
	try:	ctypes.sizeof(obj)
	except TypeError:	return False
	return True


# create an empty object to easily get the PyObject head size
cdef class _head:
	''' implementation purpose only '''
	pass

# empty tuple, reused to fasten some calls
cdef tuple _empty = ()

