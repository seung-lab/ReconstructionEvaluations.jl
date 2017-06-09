from edges import Edges
import copy
import h5py
import numpy as np

class Segment(object):

    def __init__(self, edges, seg_id=0):
        """Segment object loads relevant information for specifc segment
        """
        self.id = seg_id
    
        self.pre_neighbors = edges.post_to_pre.get(seg_id, [])
        self.post_neighbors = edges.pre_to_post.get(seg_id, [])
        self.pre_synapses = edges.pre_to_syns.get(seg_id, [])
        self.post_synapses = edges.post_to_syns.get(seg_id, [])
        print(self)

    def get_synapses(self, type='all'):
        synapses = self.pre_synapses + self.post_synapses
        if type == 'pre':
            synapses = self.pre_synapses
        elif type == 'post':
            synapses = self.post_synapses
        return synapses

    def get_neighbors(self, type='all'):
        segments = self.pre_neighbors + self.post_neighbors
        if type == 'pre':
            segments = self.pre_neighbors
        elif type == 'post':
            segments = self.post_neighbors
        return segments

    def __repr__(self):
        s  = "seg id:\t" + str(self.id) + "\n"
        s += "neighbors:\t" + str(len(self.get_neighbors())) + "\n"
        s += "\tpre:\t" + str(len(self.pre_neighbors)) + "\n"
        s += "\tpost:\t" + str(len(self.post_neighbors)) + "\n"
        s += "synapses:\t" + str(len(self.get_synapses())) + "\n"
        s += "\tpre:\t" + str(len(self.pre_synapses)) + "\n"
        s += "\tpost:\t" + str(len(self.post_synapses)) + "\n"
        return s

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
        self.edges = Edges(src_file, dst_file)
        self.original_edge_dict = {}
        self.synapses = []
        self.coords = []
        self.segments = []
        self.neighbors = []
        self.type = 'all'
        self.shared = False

    def set_segments(self, seg_ids):
        self.segments = [Segment(self.edges, seg_id) for seg_id in seg_ids]
        self.load_synapses()
        self.load_neighbors()
        print(self)

    def load_synapses(self):
        synapses = []
        for seg in self.segments:
            synapses.append(set(seg.get_synapses(self.type)))
        if self.shared:
            shared_synapses = []
            for i, syn_i in enumerate(synapses):
                for j, syn_j in enumerate(synapses):
                    if i != j:
                        shared_synapses.append(syn_i.intersection(syn_j))
            synapses = shared_synapses
        self.synapses = sum(map(list, synapses), [])
        self.load_synapse_centroids()

    def load_synapse_centroids(self):
        coords = []
        for syn in self.synapses:
            coords.append(self.edges.syn_coords[syn])
        self.coords = coords

    def load_pre_post_centroids(self):
        coords = []
        for syn in self.synapses:
            coords.append(self.edges.syn_coords_pre_post[syn])
        self.coords = coords

    def load_neighbors(self):
        neighbors = []
        for seg in self.segments:
            neighbors.append(set(seg.get_neighbors(self.type)))
        if self.shared:
            shared_neighbors = []
            for i, seg_i in enumerate(neighbors):
                for j, seg_j in enumerate(neighbors):
                    if i != j:
                        shared_neighbors.append(seg_i.intersection(seg_j))
            neighbors = shared_neighbors
        self.neighbors = sum(map(list, neighbors), [])

    def get_synapses(self):
        return self.synapses

    def get_coords(self):
        return self.coords

    def get_segments(self, neighbors=False):
        segs = [seg.id for seg in self.segments]
        segs += self.neighbors if neighbors else []
        return segs

    def get_neighbors(self):
        return self.neighbors

    def undo(self):
        self.edges.undo()

    def save(self):
        """Write update edges csv to outfile
        """
        self.edges.save()

    def get_seg_value(self, coord):
        """Lookup coordinate in the segmentation H5 file
        """
        f = h5py.File(self.segmentation_file, "r")
        dset = f['/main']
        return int(dset[tuple(coord)])

    def update_synapses(self, new_coords, pre_post_centroids=False):
        """Update the edge dicts based on the list of new synapse coords

        Run through current coords and the working list, tabulating which need
        to be removed from the current list, and what needs to be added from
        the working list.

        Then run through the "to add" and "to remove" lists, making the 
        adjustments to the edge dicts.
        """
        old_coords = self.coords

        syn_to_remove = np.ones(len(self.synapses), dtype=bool)
        syn_to_add = np.ones(len(new_coords), dtype=bool)

        for i, old_coord in enumerate(old_coords):
            for j, new_coord in enumerate(new_coords):
                if old_coord == new_coord:
                    syn_to_remove[i] = False
                    syn_to_add[j] = False

        for syn in np.array(self.synapses)[syn_to_remove]:
            self.edges.remove_edge(syn)

        # if pre_post_centroids:
        #     new_coords = zip(new_coords[::2], new_coords[1::2])
        #     old_coords = zip(self.coords[::2], self.coords[1::2])

        # for i, (old_pre, old_post) in enumerate(old_coords):
        #     for j, (new_pre, new_post) in enumerate(new_coords):
        #         if (new_pre == old_pre) & (new_post == old_post):
        #             syn_to_remove[i] = False
        #             syn_to_add[j] = False

        # for coord in np.array(new_coords)[syn_to_add].tolist():
        #     if pre_post_centroids:
        #         pre_coord, post_coord = coord
        #     else:
        #         pre_coord, post_coord = coord, coord
        #     pre = self.get_seg_value(reversed(pre_coord))
        #     post = self.get_seg_value(reversed(post_coord))
        #     if pre != 0 and post != 0:
        #         self.edges.add_edge(pre, post, pre_coord, post_coord)

    def __repr__(self):
        s  = 'no\tsyn\tcentroid\t\tpre\t\tpost\n'
        for i, (syn, coord) in enumerate(zip(self.synapses, self.coords)):
            pre = self.edges.syn_to_pre_seg[syn]
            post = self.edges.syn_to_post_seg[syn]
            s += str(i) + '\t' 
            s += str(syn) + '\t' 
            s += str(coord) + '\t'
            s += str(pre) + '\t'
            s += str(post) + '\t'
            s += '\n'
        return s
