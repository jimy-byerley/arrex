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

_arrex.declare(f16, f16, 'exxxxxx')
_arrex.declare(f32, f32, 'fxxxx')
_arrex.declare(f64, f64, 'd')
_arrex.declare(f128, f128, 'B'*16)

_arrex.declare(u8, u8, 'Bxxxxxxx')
_arrex.declare(i8, i8, 'bxxxxxxx')
_arrex.declare(u16, u16, 'Hxxxxxx')
_arrex.declare(i16, i16, 'hxxxxxx')
_arrex.declare(u32, u32, 'Ixxxx')
_arrex.declare(i16, i16, 'ixxxx')
_arrex.declare(u64, u64, 'L')
_arrex.declare(i64, i64, 'l')
