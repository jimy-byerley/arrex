list
=========

.. automodule:: arrex.list

.. autoclass:: typedlist

	.. automethod:: empty
	.. automethod:: full
	
	- Methods matching those from `list`

	.. automethod:: append
	.. automethod:: extend
	.. automethod:: insert
	.. automethod:: clear
	.. automethod:: reverse
	
	.. automethod:: index
	
	.. automethod:: __add__
	.. automethod:: __mul__
	.. automethod:: __getitem__
	.. automethod:: __setitem__
	.. automethod:: __delitem__
	.. automethod:: __iter__
	.. automethod:: __copy__
	.. automethod:: __deepcopy__
	
	- The following methods are added on top of python `list` signature, in order to manage memory in a more efficient way.
	
	.. automethod:: capacity
	.. automethod:: reserve
	.. automethod:: shrink
