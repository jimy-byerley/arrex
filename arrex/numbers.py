from . import _arrex
from struct import calcsize, pack, unpack, Struct

class StructSingle(Struct):
	def unpack(self, buffer):
		return super().unpack(buffer)[0]

for fmt in 'bBhHiIlLnNfd':
	struct = StructSingle(fmt)
	_arrex.declare(fmt, _arrex.DTypeFunctions(struct.size, struct.pack, struct.unpack, fmt))

_arrex.declare(float, _arrex.declared('d'))
_arrex.declare(int, _arrex.declared('l'))
