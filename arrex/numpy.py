import numpy.core as np
from .dtypes import declare, DDTypeExtension

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

declare(f16, DDTypeExtension(f16, 'exxxxxx', f16))
declare(f32, DDTypeExtension(f32, 'fxxxx', f32))
declare(f64, DDTypeExtension(f64, 'd', f64))
declare(f128, DDTypeExtension(f128, 'B'*16, f128))

declare(u8, DDTypeExtension(u8, 'Bxxxxxxx', u8))
declare(i8, DDTypeExtension(i8, 'bxxxxxxx', i8))
declare(u16, DDTypeExtension(u16, 'Hxxxxxx', u16))
declare(i16, DDTypeExtension(i16, 'hxxxxxx', i16))
declare(u32, DDTypeExtension(u32, 'Ixxxx', u32))
declare(i16, DDTypeExtension(i32, 'ixxxx', i32))
declare(u64, DDTypeExtension(u64, 'L', u64))
declare(i64, DDTypeExtension(i64, 'l', i64))
