import numpy as np

def load_edges(fn):
    """Load edges csv as numpy array
    """
    return np.genfromtxt(fn, delimiter=",", dtype=np.int)

def create_edge_dicts(edges):
    """Produce list of look up dicts for fast edge querying
    
    Args:
        edges: Nx7 array (see load_edges)
            synapse id, pre seg id, post seg id, syn x coord, syn y coord,
            syn z coord, psd voxel count

    Returns:
        tuple of dicts
            syn_to_segs: synapse ID returns pre & post seg IDs
            segs_to_syn: tuple of pre, post IDs looks up synapse ID
            syn_coords: synapse ID returns coords of its centroid
            syn_size: synapse ID returns its size (no. of voxels)
            seg_to_syn: seg ID returns list of synapse IDs that connect it
            pre_to_post: pre seg ID returns list of connected post seg IDs
            post_to_pre: post seg ID returns list of connected pre seg
    """

    def push_dict(d, k, v):
        """For dicts with lists, test key, then append to list
        """
        if not k in d:
            d[k] = []
        d[k].append(v)

    def unique(d):
        """For dicts with lists, make all lists unique
        """
        for k, v in d.iteritems():
            d[k] = list(set(v))

    syn_to_segs = {}
    segs_to_syn = {}
    seg_to_syn = {}
    syn_coords = {}
    syn_size = {}
    pre_to_post = {}
    post_to_pre = {}

    for i in range(0, edges.shape[0]):
        syn_to_segs[edges[i,0]] = edges[i,1:3].tolist()
        syn_coords[edges[i,0]] = edges[i,3:6].tolist()
        syn_size[edges[i,0]] = edges[i,6]
        push_dict(segs_to_syn, tuple(edges[i,1:3].tolist()), edges[i,0])
        push_dict(seg_to_syn, edges[i,1], edges[i,0])
        push_dict(seg_to_syn, edges[i,2], edges[i,0])
        push_dict(pre_to_post, edges[i,1], edges[i,2])
        push_dict(post_to_pre, edges[i,2], edges[i,1])

    unique(pre_to_post)
    unique(post_to_pre)

    return syn_to_segs, segs_to_syn, syn_coords, syn_size, seg_to_syn, \
                                                    pre_to_post, post_to_pre

def transform_coords(coords_dict, offset, s=np.array([1,1,1])):
    """Rescale & translate a dictionary of coordinates
    
    Args:
        coords_dict: dict of synapse ID to centroid (3-element numpy array)
        scale: scalar
        offset: ndarray that must match the shape of coords

    Returns:
        Updated coords_dict
    """

    for (k,v) in coords_dict.iteritems():
        coords_dict[k] = (s*v + offset).tolist()

    return coords_dict

def remap(map_dict, seg_list):
    """Remap a list of segments (can be slice of larger numpy array)

    Args:
        map_dict: dict mapping old seg id to a new seg id
        seg_list: slice of numpy array that will be overwritten

    Returns:
        seg_list will be modified with new seg ids
    """
    for x in np.nditer(seg_list, op_flags=['readwrite']):
        # not in map, object maps to itself
        x[...] = map_dict[int(x)]