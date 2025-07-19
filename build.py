import os
import shutil
from pathlib import Path
from textwrap import dedent

from Cython.Build import cythonize
from setuptools import Distribution
from setuptools import Extension
from setuptools.command.build_ext import build_ext

def generate_numbers():
    file = 'arrex/numbers.pyx'
    numbers = open(file, 'w')

    numbers.write(dedent('''
        # cython: language_level=3, cdivision=True

        cimport cython
        from cpython cimport PyObject, Py_DECREF
        from libc.stdint cimport *
        from .dtypes cimport *

        cdef DDType decl
        '''))

    template = dedent('''
        ### declare {ctype}

        cdef int pack_{layout}(object dtype, {ctype}* place, object obj) except -1:
            place[0] = obj
        cdef object unpack_{layout}(object dtype, {ctype}* place):
            return place[0]

        decl = DDType()
        decl.dsize = sizeof({ctype})
        decl.c_pack = <c_pack_t> pack_{layout}
        decl.c_unpack = <c_unpack_t> unpack_{layout}
        decl.layout = b'{layout}'

        declare('{layout}', decl)
        ''')

    for layout, ctype in [
            ('d', 'double'),
            ('f', 'float'),
            ('b', 'int8_t'),
            ('B', 'uint8_t'),
            ('h', 'int16_t'),
            ('H', 'uint16_t'),
            ('i', 'int32_t'),
            ('I', 'uint32_t'),
            ('l', 'int64_t'),
            ('L', 'uint64_t'),
            ]:
        numbers.write(template.format(layout=layout, ctype=ctype))
        
    numbers.write(dedent('''
        declare(float, declared('d'))
        declare(int, declared('l'))
        '''))
    return file

def build():
    distribution = Distribution({
        "name": "package",
        "ext_modules": cythonize([
            'arrex/dtypes.pyx', 
            'arrex/list.pyx', 
            generate_numbers(),
            ]),
    })

    cmd = build_ext(distribution)
    cmd.ensure_finalized()
    cmd.run()

    # Copy built extensions back to the project
    for output in cmd.get_outputs():
        output = Path(output)
        relative_extension = output.relative_to(cmd.build_lib)

        shutil.copyfile(output, relative_extension)
        mode = os.stat(relative_extension).st_mode
        mode |= (mode & 0o444) >> 2
        os.chmod(relative_extension, mode)

build()
