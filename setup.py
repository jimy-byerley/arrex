from distutils.core import setup, Extension
import os

try:
	from Cython.Build import cythonize
except ImportError:
	cython_modules = [Extension('arrex._arrex', ['arrex/_arrex.c'])]
else:
	cython_modules = cythonize(['arrex/_arrex.pyx'], annotate=True)

setup(
    name = 'arrex',
    version = '0.1',
    tests_require = [
		'nprint>=0.1',
		'pyglm>=1.2',
		'numpy>=1.1',
		],
    packages = ["arrex"],
    package_data = {
		"arrex": ['*.h', '*.c', '*.cpp', '*.pyx'],
		'': ['COPYING', 'COPYING.LESSER', 'README'],
		},
    ext_modules = cython_modules,
    
    author = 'Jimy Byerley',
    author_email = 'jimy.byerley@gmail.com',
    url = 'https://github.com/jimy-byerley/arrex',
    license = "GNU GPL v3",
    description = "typed arrays using any custom type as element type",
	long_description = open('README.md').read(),
)
