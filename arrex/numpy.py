import numpy.core as np
from . import _arrex

f16 = np.float16
f32 = np.float32
f64 = np.float64
f128 = np.float128

u8 = np.uint8
u16 = np.uint16
u32 = np.uint32
u64 = np.uint64

i8 = np.int8
i16 = np.int16
i32 = np.int32
i64 = np.int64

_arrex.declare(f16, _arrex.DTypeExtension(f16, 'exxxxxx', f16))
_arrex.declare(f32, _arrex.DTypeExtension(f32, 'fxxxx', f32))
_arrex.declare(f64, _arrex.DTypeExtension(f64, 'd', f64))
_arrex.declare(f128, _arrex.DTypeExtension(f128, 'B'*16, f128))

_arrex.declare(u8, _arrex.DTypeExtension(u8, 'Bxxxxxxx', u8))
_arrex.declare(i8, _arrex.DTypeExtension(i8, 'bxxxxxxx', i8))
_arrex.declare(u16, _arrex.DTypeExtension(u16, 'Hxxxxxx', u16))
_arrex.declare(i16, _arrex.DTypeExtension(i16, 'hxxxxxx', i16))
_arrex.declare(u32, _arrex.DTypeExtension(u32, 'Ixxxx', u32))
_arrex.declare(i16, _arrex.DTypeExtension(i32, 'ixxxx', i32))
_arrex.declare(u64, _arrex.DTypeExtension(u64, 'L', u64))
_arrex.declare(i64, _arrex.DTypeExtension(i64, 'l', i64))
