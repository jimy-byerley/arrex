import glm
from . import _arrex

for prec, fmt in (('u8', 'B'), ('i8', 'b'), ('u','I'), ('i','i'), ('f','f'), ('d','d')):
	for size in range(2,5):
		type = getattr(glm, prec+'vec'+str(size))
		_arrex.declare(type, type, size*fmt)

for prec, fmt in (('u','I'), ('i','i'), ('f','f'), ('d','d')):
	for size in range(2,5):
		type = getattr(glm, prec+'mat'+str(size))
		_arrex.declare(type, type, size*fmt)
		
for prec in ('f', 'd'):
	type = getattr(glm, prec+'quat')
	_arrex.declare(type, type, 4*prec)
