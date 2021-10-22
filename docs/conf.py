# -*- coding: utf-8 -*-
#
# Configuration file for the Sphinx documentation builder.
#
# This file does only contain a selection of the most common options. For a
# full list see the documentation:
# http://www.sphinx-doc.org/en/master/config


project = 'arrex'
copyright = '2021-2022, jimy byerley'
author = 'jimy byerley'

version = '0.2'			# The short X.Y version
release = 'v'+version	# The full version, including alpha/beta/rc tags


# -- General configuration ---------------------------------------------------
needs_sphinx = '3.2'
# sphinx extensions
extensions = [
    'sphinx.ext.autodoc',
    'sphinx.ext.githubpages',
    'sphinx.ext.napoleon',
    'recommonmark',
    'sphinx_rtd_theme',
]

# use a more recent version of mathjax, that can render ASCIIMATH
#mathjax_path = "https://cdn.jsdelivr.net/npm/mathjax@3/es5/startup.js"

# Add any paths that contain templates here, relative to this directory.
templates_path = ['_templates']
source_suffix = ['.rst', '.md']
master_doc = 'index' # The master toctree document

# List of patterns, relative to source directory, that match files and
# directories to ignore when looking for source files.
# This pattern also affects html_static_path and html_extra_path.
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store']

# The name of the Pygments (syntax highlighting) style to use.
add_module_names = False	# remove module names from function docs
default_role = 'code'
primary_domain = 'py'


# -- Options for HTML output -------------------------------------------------
html_logo = 'logo.png'
html_static_path = ['static']	# path to custom static files, such as images and stylesheets

html_theme = 'sphinx_rtd_theme'



def setup(app):
    app.add_css_file('custom.css')
