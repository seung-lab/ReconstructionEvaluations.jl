import edges
import copy
import h5py
import numpy as np

class Model(object):

    def __init__(self, infile, outfile, segmentation_file):
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
        self.synapse_coordinates = []
        self.working_synapse_coordinates = []
        self.synapse_idx = 0
        self.synapse_classifications = {}
        self.segments = []
        self.current_segment = 0
        self.segment_idx = 0
        self.infile = infile
        self.outfile = outfile
        self.segmentation_file = segmentation_file
        self.max_syn_id = 0

        self.read_data(infile)
        self.create_segment_list()
        self.create_synapse_list()

    def read_data(self, filename):
        """Reads data from csv file, filename, and processes it into dict
        """
        self.edge_dict = edges.create_edge_dict(edges.load_edges(filename))
        self.original_edge_dict = copy.deepcopy(self.edge_dict)
        self.max_syn_id = np.max(np.array(self.edge_dict['syn_coords'].keys()))

    def write_data(self):
        """Write update edges csv to outfile
        """
        print 'Writing edges to ' + self.outfile
        edges.write_dicts_to_edges(self.outfile, self.edge_dict)

    def read_segment_id(self, coord):
        """Lookup coordinate in the segmentation H5 file
        """
        f = h5py.File(self.segmentation_file, "r")
        dset = f['/main']
        return int(dset[tuple(coord)])

    def create_segment_list(self):
        """Creates a list of unique segments in edge_dict"""
        self.segments = self.edge_dict['seg_to_syn'].keys()
        self.segments.sort()

    def create_synapse_list(self):
        """Creates a list of unique synapses in edge_dict"""
        self.synapses = self.edge_dict['syn_coords'].keys()

    def next_segment(self):
        """Returns next synapse ID in list of synapses"""
        self.segment_idx += 1
        self.set_segment(self.segments[self.segment_idx])
        return self.current_segment

    def prev_segment(self):
        """Returns previous synapse ID in list of synapses"""
        self.segment_idx -= 1
        self.set_segment(self.segments[self.segment_idx])
        return self.current_segment

    def set_segment(self, seg_id):
        print 'set segment to ' + str(seg_id)
        self.current_segment = seg_id
        self.segment_idx = self.segments.index(seg_id)
        print str(self.segment_idx) + ' / ' + str(len(self.segments))

    def load_synapses(self):
        """Update synapse list of IDs based on the current segment & update
        the list of synapse coordinates
        """
        self.synapses = self.edge_dict['seg_to_syn'][self.current_segment]
        self.synapse_coordinates = []
        syn_coords_pre_post = self.edge_dict['syn_coords_pre_post']
        for s in self.synapses:
            self.synapse_coordinates.extend(syn_coords_pre_post[s])
    
    def get_synapse_coordinates(self):
        return self.synapse_coordinates

    # def reset_synapses(self):
    #     """Replace working synapse list for current seg with original list
    #     """
    #     print 'Reset synapses for ' + str(self.current_segment)
    #     seg_id = self.current_segment
    #     seg_to_syn = self.edge_dict['seg_to_syn']
    #     original_seg_to_syn = self.original_edge_dict['seg_to_syn']
    #     seg_to_syn[seg_id] = original_seg_to_syn[seg_id]

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

    def next_synapse(self):
        """Returns next synapse ID in list of synapses"""
        self.synapse_idx += 1
        return self.current_synapse

    def prev_synapse(self):
        """Returns previous synapse ID in list of synapses"""
        self.synapse_idx -= 1
        return self.current_synapse

    def classify_synapse(self, classification):
        """Classifies current synapse as class"""
        self.synapse_classifications[self.current_synapse] = classification

    @property
    def num_segments(self):
        return len(self.segments)

    @property
    def num_classified(self):
        return len(self.synapse_classifications)

    @property
    def num_synapses(self):
        return len(self.synapses)

    @property
    def current_synapse(self):
        """Returns synapse ID of current synapse"""
        #TODO: raise an error if idx out of bounds
        return self.synapses[self.synapse_idx]

#Tests
if __name__ == '__main__':
    assert len(sys.argv) > 2
    infile = sys.argv[1]
    outfile = "synapse_scroller_tmp.csv"
    m = Model(infile, outfile)
    import pdb; pdb.set_trace()
    print m.current_synapse, m.next_synapse(), m.prev_synapse()
    m.classify_synapse(3)
    print m.synapse_classifications
