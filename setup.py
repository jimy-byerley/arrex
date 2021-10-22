from setuptools import setup, Extension
import os

try:
	from Cython.Build import cythonize
except ImportError:
	cython_modules = [
				Extension('arrex.dtypes', ['arrex/dtypes.c']),
				Extension('arrex.list', ['arrex/list.c']),
				Extension('arrex.numbers', ['arrex/numbers.c']),
				]
else:
	cython_modules = cythonize(['arrex/dtypes.pyx', 'arrex/list.pyx', 'arrex/numbers.pyx'], annotate=True)

setup(
	# package declaration
	name = 'arrex',
	version = '0.2',
	tests_require = [
		'pnprint>=1.0',
		'pyglm>=1.2',
		'numpy>=1.1',
		],
	
	# sources declaration
	packages = ["arrex"],
	package_data = {
		"arrex": ['*.h', '*.c', '*.cpp', '*.pyx'],
		'': ['COPYING', 'COPYING.LESSER', 'README'],
		},
	ext_modules = cython_modules,
	
	# metadata for pypi
	author = 'Jimy Byerley',
	author_email = 'jimy.byerley@gmail.com',
	url = 'https://github.com/jimy-byerley/arrex',
	license = "GNU LGPL v3",
	description = "typed arrays using any custom type as element type",
	long_description = open('README.md').read(),
	long_description_content_type = 'text/markdown',
)
