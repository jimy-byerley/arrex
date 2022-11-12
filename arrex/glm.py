import glm
from .dtypes import declare, DDTypeExtension
from struct import calcsize
import sys

def machine_wordsize():
    num_bytes = 0
    maxint = sys.maxsize
    while maxint > 0:
        maxint = maxint >> 8
        num_bytes += 1
    return num_bytes
    
def align(pack):
	remain = calcsize(pack) % wordsize
	if remain:	
		pack += 'x' * (wordsize - remain)
	return pack

wordsize = machine_wordsize()

for prec, fmt in (
			('u8', 'B'), ('i8', 'b'), ('u16','H'), ('i16','h'), ('u64','Q'), ('i64','q'), 
			('u','I'), ('i','i'), 
			('f','f'), ('d','d')):
	for size in range(2,5):
		type = getattr(glm, prec+'vec'+str(size))
		declare(type, DDTypeExtension(type, align(size*fmt), type))

for prec, fmt in (('u','I'), ('i','i'), ('f','f'), ('d','d')):
	for size in range(2,5):
		type = getattr(glm, prec+'mat'+str(size))
		declare(type, DDTypeExtension(type, align(fmt*size**2), type))
		
for fmt in ('f', 'd'):
	type = getattr(glm, fmt+'quat')
	declare(type, DDTypeExtension(type, align(fmt*4), type))
