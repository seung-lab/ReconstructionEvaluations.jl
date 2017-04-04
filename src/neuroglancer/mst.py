# Functions for handling the MST
 import h5py

def load_mst_dict(fn):
	"""Open H5 file with "dend" dset & create child-parent dict
	"""
	f = h5py.File(fn, "r")
	return create_child_to_parent_dict(f["dend"])

def create_child_to_parent_dict(dend):
	"""Create dict of child ID to list of parent IDs

	Our MSTs are one-to-many for x->y, x,y = dend[:,i]
	"""
	# cpd = {}
	# for i in range(dend.shape[1]):
	# 	child, parent = dend[:,i]
	# 	cpd[child] = parent	
	# return cpd
	cpd = {}
	for i in range(dend.shape[1]):
		child, parent = dend[:,i]
		if child not in cpd:
			cpd[child] = [parent]
		else:
			cpd[child].append(parent)		
	return cpd	

def create_node_to_root_dict(cpd):
	"""Create dict of node ID to root ID in MST

	Args:
		cpd: child-parent dict (see create_child_to_parent_dict)

	Outputs:
		node-root dict
	"""
	nrd = {}
	children = []
	for k, v in cpd:
		if v in cpd:
			children.append(k)
		else:
			root = v
			for child in children:
				nrd[child] = root
			children = []
	return nrd