from arrex import *
import arrex.numbers
from nprint import nprint

# test floats
a = typedlist(dtype='f')
a.append(1)
a.append(1.2)

nprint(a, repr(a.dtype))
assert len(a) == 2
assert a[0] == 1
assert type(a[0]) == float
assert a.dtype == 'f'

# test ints
a = typedlist(dtype='h')
a.append(1)
a.append(4)

nprint(a, repr(a.dtype))
assert len(a) == 2
assert a[0] == 1
assert type(a[0]) == int
assert a.dtype == 'h'

# test automatic type deduction
a = typedlist([1, 2, 3, 5])
assert a.dtype == 'l'
assert len(a) == 4
nprint(a, repr(a.dtype))

