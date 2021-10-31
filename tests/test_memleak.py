from arrex import typedlist
import sys
import gc

buffs = {}

buffs[0] = bytes(5)

a = typedlist([1,2,3])
buffs[1] = a.owner
b = a * 500
buffs[2] = b.owner

last = a.owner
for j in range(500):
	for i in range(10000):
		a.append(i)
	if a.owner is not last:
		buffs[(3,j)] = last = a.owner

del a, b, last
gc.collect()

for k,v in buffs.items():
	print('{}:  len={}, id=0x{:x}, rc={}'.format(k, len(v), id(v), sys.getrefcount(v)))
