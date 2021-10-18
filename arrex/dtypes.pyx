# cython: language_level=3, cdivision=True

cimport cython
from cpython cimport PyObject, PyTypeObject
from libc.string cimport memcpy

import struct

cdef extern from "Python.h":
	object PyBytes_FromStringAndSize(const char *v, Py_ssize_t len)
	char *PyBytes_AsString(object)


	

cdef class DDType:
	''' base class for a dtype
		DO NOT USE THIS CLASS FROM PYTHON, use on of its specialization instead 
	'''
	
	def __repr__(self):
		if isinstance(self.key, type):
			return '<dtype {}>'.format(self.key.__name__)
		elif isinstance(self.key, str):
			return '<dtype {}>'.format(repr(self.key))
		else:
			return '<dtype at {}>'.format(id(self))
	

def DDTypeClass(type):
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
	
	return DDTypeFunctions(dsize, pack, unpack, layout)
	
def DDTypeStruct(struct):
	''' create a dtype from a Struct object from module `struct` '''
	return DDTypeFunctions(struct.size, struct.pack, struct.unpack, struct.format)
	

cdef class DDTypeFunctions(DDType):
	''' create a dtype from pure python pack and unpack functions '''
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
		elif dsize is None:
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
		
		
cdef class DDTypeExtension(DDType):
	''' create a dtype for a C extension type.
	
		This is the most efficient kind of dtype in term of operating time.
		
		In order to put an extension object into an array, it satisfy the following conditions:
		
		- have fixed size known at the time of dtype creation (so any array element has the same)
		- contain only byte copiable data (so nothing particular is done when copying/destroying the objects)
		
		WARNING:  These conditions MUST be ensured by the user when declaring an extension type as a dtype
	'''
	cdef public type type
	cdef public object constructor
	
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
		self.type = ext
		self.constructor = constructor
		
	cdef void * _raw(self, obj):
		return (<void*><PyObject*> obj) + (<PyTypeObject*>self.type).tp_basicsize - self.dsize
	
	cdef int _ext_pack(self, void* place, object obj) except -1:
		if type(obj) is not self.type:
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
		''' allow serialization of the dtype with the array (particularly useful for anonymous dtypes) '''
		return type(self), (self.type, self.layout, self.constructor)

		
		

# dictionnary of compatible packed types
cdef dict _declared = {}	# {python type: dtype}
	
cpdef declare(key, DDType dtype):
	''' declare(dtype, constructor=None, format=None)
	
		declare a new dtype 
	'''
	if not dtype.key:	
		dtype.key = key
	_declared[key] = dtype
	
cpdef DDType declared(key):
	''' return the content of the declaration for the givne dtype '''
	if isinstance(key, DDType):
		return key
	else:
		dtype = _declared.get(key)
		if dtype is None:
			raise TypeError('dtype {} is not declared'.format(key))
		return <DDType> dtype



# create an empty object to easily get the PyObject head size
cdef class _head:
	''' implementation purpose only '''
	pass

# empty tuple, reused to fasten some calls
cdef tuple _empty = ()

