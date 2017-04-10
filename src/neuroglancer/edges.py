import numpy as np
import csv
import pickle
import h5py
from ast import literal_eval as make_tuple

def load_edges(fn, synaptor=False):
    """Load edges csv from Synaptor as numpy array

    Args:
        fn: filepath to Synaptor edge csv file
        synaptor: if edges are generated from synaptor or are plain csv
            Synaptor generates edges as a csv with embedded lists
            plain csv would be everything strictly separated by commas

    Returns:
        Nx7 numpy array:
            [:,0] synapse ID
            [:,1] pre seg ID
            [:,2] post seg ID
            [:,3:6] synapse centroid coordinates
            [:,6] synapse psd voxel count
            [:,7:] additional columns (e.g. pre & post coords)
    """

    if synaptor:
        edges = []
        with open(fn, 'rb') as f:
            edge_reader = csv.reader(f, delimiter=';')
            for row in edge_reader:
                seg_ids =  make_tuple(row[1])
                coords = make_tuple(row[2])
                edges.append([int(row[0]), seg_ids[0], seg_ids[1], 
                        coords[0], coords[1], coords[2], int(row[3])])
        return np.array(edges)
    else:
        return np.genfromtxt(fn, delimiter=",", dtype=int)


def save_edges(fn, edges):
    """Save out edge list as plain csv of ints
    """
    np.savetxt(fn, edges, delimiter=',', fmt='%d')

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

def create_edge_dict(edges):
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
    syn_to_segs = {}
    segs_to_syn = {}
    seg_to_syn = {}
    syn_coords = {}
    syn_size = {}
    pre_to_post = {}
    post_to_pre = {}
    syn_coords_pre_post = {}

    for i in range(0, edges.shape[0]):
        syn_to_segs[edges[i,0]] = edges[i,1:3].tolist()
        syn_coords[edges[i,0]] = edges[i,3:6].tolist()
        if edges.shape[1] > 7:
            syn_coords_pre_post[edges[i,0]] = [edges[i,7:10].tolist(), 
                                                        edges[i,10:13].tolist()]
        else:
            syn_coords_pre_post[edges[i,0]] = [syn_coords[edges[i,0]], 
                                                        syn_coords[edges[i,0]]]
        syn_size[edges[i,0]] = edges[i,6]
        push_dict(segs_to_syn, tuple(edges[i,1:3].tolist()), edges[i,0])
        push_dict(seg_to_syn, edges[i,1], edges[i,0])
        push_dict(seg_to_syn, edges[i,2], edges[i,0])
        push_dict(pre_to_post, edges[i,1], edges[i,2])
        push_dict(post_to_pre, edges[i,2], edges[i,1])

    unique(pre_to_post)
    unique(post_to_pre)

    labels = 'syn_to_segs', 'segs_to_syn', 'syn_coords', \
                'syn_coords_pre_post', 'syn_size', 'seg_to_syn', \
                'pre_to_post', 'post_to_pre'
    edge_dict = syn_to_segs, segs_to_syn, syn_coords, syn_coords_pre_post, \
                            syn_size, seg_to_syn, pre_to_post, post_to_pre
    
    return dict(rel for rel in zip(labels, edge_dict))

def write_dicts_to_edges(fn, edge_dict):
    """Write set of edge dicts back to edges csv file
    """
    with open(fn, 'wb') as f:
        w = csv.writer(f, delimiter=',')
        for syn, segs in edge_dict['syn_to_segs'].iteritems():
            row = []
            row.append(syn)
            row.extend(segs)
            row.extend(edge_dict['syn_coords'][syn])
            row.extend(edge_dict['syn_coords_pre_post'][syn][0])
            row.extend(edge_dict['syn_coords_pre_post'][syn][1])
            w.writerow(row)

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