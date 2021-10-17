import glm
from . import _arrex
from struct import calcsize

native = 8	# for 64bit machines only

for prec, fmt in (
			('u8', 'B'), ('i8', 'b'), ('u16','H'), ('i16','h'), ('u64','Q'), ('i64','q'), 
			('u','I'), ('i','i'), 
			('f','f'), ('d','d')):
	for size in range(2,5):
		type = getattr(glm, prec+'vec'+str(size))
		pack = size*fmt
		remain = calcsize(pack) % native
		if remain:	pack += 'x' * (native - remain)
		_arrex.declare(type, _arrex.DTypeExtension(type, pack, type))

for prec, fmt in (('u','I'), ('i','i'), ('f','f'), ('d','d')):
	for size in range(2,5):
		type = getattr(glm, prec+'mat'+str(size))
		_arrex.declare(type, _arrex.DTypeExtension(type, size*fmt, type))
		
for prec in ('f', 'd'):
	type = getattr(glm, prec+'quat')
	_arrex.declare(type, _arrex.DTypeExtension(type, 4*prec, type))
