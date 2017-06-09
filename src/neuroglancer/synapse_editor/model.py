import edges
import copy
import h5py
import numpy as np

class Segment(object):

    def __init__(self, edge_dict, seg_id=0):
        """Segment object loads relevant information for specifc segment
        """
        self.edge_dict = edge_dict
        self.seg_id = seg_id
    
        self.pre_neighbors
        self.post_neighbors
        self.pre_synapses
        self.post_synapses

        self.neighbors = edge_dict['seg_to_neighbors'][seg_id]
        self.synapses = edge_dict['seg_to_syn'][seg_id]

    def get_synapses(self):
        return self.synapses

    def get_neighbors(self):
        return self.neighbors

    def __repr__(self):
        s  = "seg id:\t" + str(self.seg_id) + "\n"
        s += "neighbors:\t" + str(len(self.neighbors)) + "\n"
        s += "synapses:\t" + str(len(self.synapses)) + "\n"

class Model(object):

    def __init__(self, src_file, dst_file):
        """Model object governs the edge dictionaries

        Attributes:
            original_edge_dict: set of edge dicts to reset changes
            edge_dict: working set of dicts
            synapses: list of current synapses to be displayed
            synapse_idx: index of current synapse
            synapse_classifications: dict of synapse labelings
            segments: list of segments to be displayed
            current_segment: ID of segment being viewed
            segment_idx: index of current segment
        """
        self.edge_dict = {}
        self.original_edge_dict = {}
        self.synapses = []
        self.coords = []
        self.segments = []
        self.neighbors = []
        self.src_file = src_file
        self.dst_file = dst_file

        self.load(src_file)

    def set_segments(self, seg_ids):
        self.segments = [Segment(seg_id) for seg_id in seg_ids]

    def load_all_synapses(self):

    def load_shared_synapses(self):

    def load_pre_synapses(self):

    def load_post_synapses(self):

    def load_synapse_centroids(self):

    def load_pre_post_centroids(self):

    def load_all_neighbors(self):

    def load_shared_neighbors(self):

    def load_pre_neighbors(self):

    def load_post_neighbors(self):

    def get_synapses(self):

    def get_segments(self):

    def get_neighbors(self):

    def reset(self):

    def update_synapses(self, coords):
        edges.add_edge
        edges.remove_edge

    def load(self, filename):
        """Reads data from csv file, filename, and processes it into dict
        """
        self.edge_dict = edges.create_edge_dict(edges.load_edges(filename))
        self.original_edge_dict = copy.deepcopy(self.edge_dict)

    def write(self):
        """Write update edges csv to outfile
        """
        print 'Writing edges to ' + self.outfile
        edges.write_dicts_to_edges(self.outfile, self.edge_dict)

    def get_seg_value(self, coord):
        """Lookup coordinate in the segmentation H5 file
        """
        f = h5py.File(self.segmentation_file, "r")
        dset = f['/main']
        return int(dset[tuple(coord)])

    def update_dicts(self, current_synapse_coordinates):
        """Update the edge dicts based on the list of working synapse coords

        Run through current coords and the working list, tabulating which need
        to be removed from the current list, and what needs to be added from
        the working list.

        Then run through the "to add" and "to remove" lists, making the 
        adjustments to the edge dicts.
        """
        coords = current_synapse_coordinates
        temp_coords = zip(coords[::2], coords[1::2])
        coords = self.synapse_coordinates
        cur_coords = zip(coords[::2], coords[1::2])

        syn_to_remove = np.ones(len(self.synapses), dtype=bool)
        syn_to_add = np.ones(len(temp_coords), dtype=bool)
        for i, (cur_pre, cur_post) in enumerate(cur_coords):
            for j, (temp_pre, temp_post) in enumerate(temp_coords):
                if (temp_pre == cur_pre) & (temp_post == cur_post):
                    syn_to_remove[i] = False
                    syn_to_add[j] = False

        for syn in np.array(self.synapses)[syn_to_remove]:
            print 'deleting synapse no. ' + str(syn)
            pre, post = self.edge_dict['syn_to_segs'][syn]
            del self.edge_dict['syn_to_segs'][syn]
            del self.edge_dict['syn_coords'][syn]
            del self.edge_dict['syn_size'][syn]
            del self.edge_dict['syn_coords_pre_post'][syn]
            self.edge_dict['seg_to_syn'][pre].remove(syn)
            self.edge_dict['seg_to_syn'][post].remove(syn)
            shared_synapses = self.edge_dict['segs_to_syn'][(pre, post)]
            if len(shared_synapses) > 1:
                self.edge_dict['segs_to_syn'][(pre, post)].remove(syn)
            else:
                del self.edge_dict['segs_to_syn'][(pre, post)]
                self.edge_dict['pre_to_post'][pre].remove(post)
                self.edge_dict['post_to_pre'][post].remove(pre)

        for pre_coord, post_coord in np.array(temp_coords)[syn_to_add].tolist():
            pre = self.read_segment_id(reversed(pre_coord))
            post = self.read_segment_id(reversed(post_coord))
            print 'Proposed pre: ' + str(pre) + ':' + str(pre_coord)
            print 'Proposed post: ' + str(post) + ':' + str(post_coord)
            if (pre == self.current_segment) | (post == self.current_segment):
                self.max_syn_id += 1
                s = self.max_syn_id
                print 'adding synapse no. ' + str(s)
                points = np.array([pre_coord, post_coord])
                center = np.round(np.mean(points, axis=0)).astype(int).tolist()
                self.edge_dict['syn_to_segs'][s] = [pre, post]
                self.edge_dict['syn_coords'][s] = center
                self.edge_dict['syn_size'][s] = 0
                self.edge_dict['syn_coords_pre_post'][s] = [pre_coord, post_coord]
                self.edge_dict['segs_to_syn'][(pre, post)] = s
                edges.push_dict(self.edge_dict['seg_to_syn'], pre, s)
                edges.push_dict(self.edge_dict['seg_to_syn'], post, s)
                edges.push_dict(self.edge_dict['pre_to_post'], pre, post)
                edges.push_dict(self.edge_dict['post_to_pre'], post, pre)
            else:
                print 'Trying to add synapse at ' + str(pre_coord) + ',' + \
                        str(post_coord) + ', but not part of segment ' + \
                        str(self.current_segment) + '. Move synapse or ' + \
                        'switch to appropriate segments.'

        edges.unique(self.edge_dict['pre_to_post'])
        edges.unique(self.edge_dict['post_to_pre'])
        self.load_synapses()
