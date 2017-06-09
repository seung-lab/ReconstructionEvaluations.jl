import numpy as np
import csv
import pickle
import h5py
from ast import literal_eval as make_tuple

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

class Edges(object):

    def __init__(self, src_fn, dst_fn, offset=np.array([0,0,0])):
        """Contains dictionaries for fast edge lookup & manipulation


        Attributes:
            src_fn: location of edges csv
            dst_fn
            syn_to_pre_seg: synapse ID returns pre ID
            syn_to_post_seg: synapse ID returns post ID
            segs_to_syn: tuple of pre, post IDs looks up synapse ID
            syn_coords: synapse ID returns coords of its centroid
            syn_coords_pre_post: syn ID returns 2 coords - pre/post centroids
            syn_size: synapse ID returns its size (no. of voxels)
            pre_to_syns: seg ID returns list of presynaptic synapse IDs
            post_to_syns: seg ID returns list of postsynaptic synapse IDs
            post_to_pre: seg ID returns list of connected pre seg IDs
            pre_to_post: seg ID returns list of connected post seg IDs
        """
        self.src_fn = src_fn
        self.dst_fn = dst_fn
        self.offset = offset
        self.syn_to_pre_seg = {}
        self.syn_to_post_seg = {}
        self.segs_to_syn = {}
        self.pre_to_syns = {}
        self.post_to_syns = {}
        self.syn_coords = {}
        self.syn_coords_pre_post = {}
        self.syn_size = {}
        self.post_to_pre = {}
        self.pre_to_post = {}
        self.max_syn = 99999999
        self.edit_stack = []
        self.load()

    def load(self):
        """Load edges csv into set of dictionaries as object attributes

        edges csv format
            [:,0] synapse ID
            [:,1] pre seg ID
            [:,2] post seg ID
            [:,3:6] synapse centroid coordinates
            [:,6] synapse psd voxel count
            [:,7:] additional columns (e.g. pre & post coords)
        """
        e = np.genfromtxt(self.src_fn, delimiter=",", dtype=int)
        e[:,3:6] -= self.offset
        e[:,7:10] -= self.offset 
        e[:,10:13] -= self.offset 

        for i in range(0, e.shape[0]):
            self.syn_to_pre_seg[e[i,0]] = e[i,1]
            self.syn_to_post_seg[e[i,0]] = e[i,2]
            self.syn_coords[e[i,0]] = list(e[i,3:6])
            if e.shape[1] > 7:
                self.syn_coords_pre_post[e[i,0]] = [e[i,7:10].tolist(), 
                                                        e[i,10:13].tolist()]
            else:
                self.syn_coords_pre_post[e[i,0]] = [syn_coords[e[i,0]], 
                                                            syn_coords[e[i,0]]]
            self.syn_size[e[i,0]] = e[i,6]
            push_dict(self.segs_to_syn, tuple(e[i,1:3].tolist()), e[i,0])
            push_dict(self.pre_to_syns, e[i,1], e[i,0])
            push_dict(self.post_to_syns, e[i,2], e[i,0])
            push_dict(self.post_to_pre, e[i,2], e[i,1])
            push_dict(self.pre_to_post, e[i,1], e[i,2])

        unique(self.post_to_pre)
        unique(self.pre_to_post)
        self.max_syn = np.max(np.array(self.syn_coords.keys()))

    def save(self):
        """Write set of edge dicts back to edges csv file
        """
        with open(self.dst_fn, 'wb') as f:
            w = csv.writer(f, delimiter=',')
            synapses = self.syn_to_pre_seg.keys()
            pre_segs = self.syn_to_pre_seg.values()
            post_segs = self.syn_to_post_seg.values()
            for syn, pre_seg, post_seg in zip(synapses, pre_segs, post_segs):
                row = []
                row.append(syn)
                row.extend([pre_seg, post_seg])
                row.extend(self.syn_coords[syn])
                row.append(self.syn_size[syn])
                row.extend(self.syn_coords_pre_post[syn][0])
                row.extend(self.syn_coords_pre_post[syn][1])
                w.writerow(row)

    def remove_edge(self, syn):
        """Remove edge from all the dictionaries

        Args:
            syn: synapse ID
        
        Returns:
            Updated dictionaries
        """
        print 'deleting synapse no. ' + str(syn)
        pre = self.syn_to_pre_seg[syn]
        post = self.syn_to_post_seg[syn]
        del self.syn_to_pre_seg[syn]
        del self.syn_to_post_seg[syn]
        del self.syn_coords[syn]
        del self.syn_size[syn]
        del self.syn_coords_pre_post[syn]
        self.pre_to_syns[pre].remove(syn)
        self.post_to_syns[post].remove(syn)
        shared_synapses = self.segs_to_syn[(pre, post)]
        if len(shared_synapses) > 1:
            self.segs_to_syn[(pre, post)].remove(syn)
        else:
            del self.segs_to_syn[(pre, post)]
            self.post_to_pre[post].remove(pre)
            self.pre_to_post[pre].remove(post)
        self.edit_stack.append(syn)

    def add_edge(self, pre, post, pre_coord, post_coord):
        """Add edge to the edge dictionaries

        Args:
            pre: presynaptic seg ID
            post: postsynaptic seg ID
            pre_coord: presynaptic synapse coordinate
            post_coord: postsynaptic synapse coordinate
        
        Returns:
            Updated dictionaries
        """
        self.max_syn += 1
        syn = self.max_syn
        print 'adding synapse no. ' + str(syn)
        points = np.array([pre_coord, post_coord])
        center = np.round(np.mean(points, axis=0)).astype(int).tolist()
        self.syn_to_pre_segs[syn] = pre
        self.syn_to_pre_segs[syn] = post
        self.syn_coords[syn] = center
        self.syn_size[syn] = 0
        self.syn_coords_pre_post[syn] = [pre_coord, post_coord]
        self.segs_to_syn[(pre, post)] = syn
        push_dict(self.pre_to_syns, pre, syn)
        push_dict(self.post_to_syns, post, syn)
        push_dict(self.pre_to_post, pre, post)
        push_dict(self.post_to_pre, post, pre)

        self.post_to_pre[pre] = list(set(self.post_to_pre[pre]))
        self.post_to_pre[post] = list(set(self.post_to_pre[post]))

        self.edit_stack.append(syn)

    def undo(self):
        syn = self.edit_stack(pop)


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
        if int(x) in map_dict: 
            x[...] = map_dict[int(x)]

def find_nearest(pt, pts):
    """Find points in pts that's nearest to pt (return first closest)

    Args:
        pt: 1xN np.array as point to be searched against
        pts: MxN np.array as list of points to be searched against

    Returns:
        The row index of the nearest point, as well as the coordinates of the
        nearest point.
    """
    idx = (np.linalg.norm(pts - pt, axis=1)).argmin()
    return pts[idx], idx

def remap_synapse_centroids_from_pickle(edges, pre_post_dicts):
    """Associate pre & post segment centroids from synapse centroid.

    Ignacio T associated each synapse centroid with a pre and post centroid &
    stored the information in a pickle. This method will reassociate those
    additional centroids with our edge list.

    Args:
        edges: Nx7 numpy array of edges (see `load_edges`)
        pre_post_dicts: list of two dicts - segID to centroid - for pre & post
    
    Returns:
        new edge list with additional columns for the two additional centroids
    """
    new_edges_shape = np.array(edges.shape) + np.array([0,6])
    new_edges = np.zeros(tuple(new_edges_shape), dtype=edges.dtype)
    new_edges[:,:-6] = edges
    premap = pre_post_dicts[0]
    postmap = pre_post_dicts[1]
    for row in new_edges:
        pre = row[1]
        post = row[2]
        centr = row[3:6]
        possible_pre = np.array(premap[pre])[::2]
        possible_post = np.array(postmap[post])[1::2]
        row[7:10], _ = find_nearest(centr, possible_pre)
        row[10:13], _ = find_nearest(centr, possible_post)
    return new_edges

def load_map_dict(fn):
    """Load a Python pickled dict mapping old IDs to new IDs
    """
    return pickle.load(open(fn, "rb"))

def remap_edge_list(map_fn, edge_fn, new_fn):
    map_dict = load_map_dict(map_fn)
    edges = load_edges(edge_fn)
    remap(map_dict, edges[:,1])
    remap(map_dict, edges[:,2])
    save_edges(new_fn, edges)

def remap_seg_list(map_fn, seg_fn, new_fn):
    map_dict = load_map_dict(map_fn)
    segs = np.genfromtxt(seg_fn, delimiter=";", dtype=int)
    remap(map_dict, segs[:,0])
    np.savetxt(new_fn, segs, delimiter=';', fmt='%d')

def load_labels(fn, delimiter=',', id_col=0, label_col=1):
    """
    Load ID list with label IDs
    e.g. use to load segment label, or synapse label
    """
    d = np.genfromtxt(fn, delimiter=delimiter, dtype=int)
    label_to_id = {}
    id_to_label = {}
    for i in range(d.shape[0]):
        push_dict(label_to_id, d[i,label_col], d[i,id_col])
        id_to_label[d[i,id_col]] = d[i,label_col]
    return label_to_id, id_to_label

def include_unlabeled(label_to_id, id_to_label, ids):
    """
    Include labels of -1 for elements not in label dicts

    See load_labels for inputs
    """
    for i in ids:
        if i not in id_to_label:
            id_to_label[i] = -1
            push_dict(label_to_id, -1, i)
    return label_to_id, id_to_label
