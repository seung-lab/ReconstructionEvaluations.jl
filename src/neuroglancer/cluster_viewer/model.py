import edges
import copy
import h5py
import numpy as np
from collections import Counter

class Segment(object):

    def __init__(self, edge_dict, seg_id=0):
        """Segment object loads relevant information for specifc segment
        """
        self.edge_dict = edge_dict
        self.seg_id = seg_id
        self.prepost = edge_dict['seg_prepost'][seg_id]
        self.label = edge_dict['seg_to_label'][seg_id]
        self.neighbors = edge_dict['seg_to_neighbors'][seg_id]
        self.neighbor_labels = {}
        for neighbor_id in self.neighbors:
            k = edge_dict['seg_to_label'][neighbor_id]
            edges.push_dict(self.neighbor_labels, k, neighbor_id)
        self.synapses = edge_dict['seg_to_syn'][seg_id]
        self.synapse_labels = {}
        for syn_id in self.synapses:
            k = edge_dict['syn_to_label'][syn_id]
            edges.push_dict(self.synapse_labels, k, syn_id)

    def get_synapses(self):
        return self.synapses

    def get_synapses_by_label(self, label):
        if label in self.synapse_labels:
            return self.synapse_labels[label]
        else:
            return []

    def get_synapses_by_neighbor_label(self, label):
        synapses = []
        if label in self.neighbor_labels:
            segs_to_syn = self.edge_dict['segs_to_syn']
            for seg in self.neighbor_labels[label]:
                k = (self.seg_id, seg)
                if (seg, self.seg_id) in segs_to_syn:
                    synapses.extend(segs_to_syn[(seg, self.seg_id)])
                if (self.seg_id, seg) in segs_to_syn:
                    synapses.extend(segs_to_syn[(self.seg_id, seg)])
        return synapses

    def get_neighbors(self):
        return self.neighbors

    def get_neighbors_by_label(self, label):
        if label in self.neighbor_labels:
            return self.neighbor_labels[label]
        else:
            return []

    def get_shared_synapses(self, neighbor_id):
        """Return synapses between seg and neighbor
        """
        pre = []
        post = []
        k = (self.seg_id, neighbor_id)
        if k in self.edge_dict['segs_to_syn']:
            pre = self.edge_dict['segs_to_syn'][k]
        k = (neighbor_id, self.seg_id)
        if k in self.edge_dict['segs_to_syn']:
            post = self.edge_dict['segs_to_syn'][k]
        return pre, post
        

    def get_neighbors_with_rank(self):
        """Return list of tuples: (neighbor_id, no. synapses shared)
        """
        rank = []
        for n in self.neighbors:
            shared_synapses = self.get_shared_synapses(n)
            rank.append((n, len(shared_synapses[0]), len(shared_synapses[1])))
        return rank

    # def __str__(self):
    #     s  = "seg id:\t" + str(self.seg_id) + "\n"
    #     s += ("pre" if self.prepost == 0 else "post") + "\n"
    #     s += "label:\t" + str(self.label) + "\n"
    #     s += "neighbors:\t" + str(len(self.neighbors)) + "\n"
    #     for k,v in self.neighbor_labels.iteritems():
    #         s += "\t" + str(k) + ":\t" + str(len(v)) + "\n"
    #     s += "synapses:\t" + str(len(self.synapses)) + "\n"
    #     for k,v in self.synapse_labels.iteritems():
    #         s += "\t" + str(k) + ":\t" + str(len(v)) + "\n"
    #     return s

    def __repr__(self):
        s  = "seg id:\t" + str(self.seg_id) + "\n"
        s += ("pre" if self.prepost == 0 else "post") + "\n"
        s += "label:\t" + str(self.label) + "\n"
        s += "neighbors:\t" + str(len(self.neighbors)) + "\n"
        for k,v in self.neighbor_labels.iteritems():
            s += "\t" + str(k) + ":\t" + str(len(v)) + "\n"
        s += "synapses:\t" + str(len(self.synapses)) + "\n"
        for k,v in self.synapse_labels.iteritems():
            s += "\t" + str(k) + ":\t" + str(len(v)) + "\n"
        return s

class Model(object):

    def __init__(self, edges_fn, seg_label_fn, syn_label_fn):
        """Model object governs the edge dictionaries

        Attributes:
            edge_dict: working set of dicts
            segments: list of segments to be displayed
            segment: ID of segment being viewed
            segment_idx: index of current segment
        """
        self.edge_dict = {}
        self.segments = []
        self.segment = None
        self.index = 0

        self.read_data(edges_fn, seg_label_fn, syn_label_fn)
        self.create_segment_list()

    def read_data(self, edges_fn, seg_label_fn, syn_label_fn):
        """Reads data from csv file, filename, and processes it into dict
        """
        offset = np.array([17409,16385,16385])
        e = edges.load_edges(edges_fn, offset=offset)
        self.edge_dict = edges.create_edge_dict(e)
        segs = self.edge_dict['seg_to_neighbors'].keys()
        syns = self.edge_dict['syn_to_segs'].keys()
        label_to_segs, seg_to_label = edges.load_labels(seg_label_fn, 
                                    delimiter='\t', id_col=1, label_col=2)
        label_to_segs, seg_to_label = edges.include_unlabeled(label_to_segs, 
                                    seg_to_label, segs)
        self.edge_dict['label_to_segs'] = label_to_segs
        self.edge_dict['seg_to_label'] = seg_to_label
        label_to_syn, syn_to_label = edges.load_labels(syn_label_fn, 
                                    delimiter=',', id_col=0, label_col=1)
        label_to_syn, syn_to_label = edges.include_unlabeled(label_to_syn, 
                                    syn_to_label, syns)        
        self.edge_dict['label_to_syn'] = label_to_syn
        self.edge_dict['syn_to_label'] = syn_to_label

    def create_segment_list(self):
        """Creates a list of unique segments in edge_dict"""
        self.segments = self.edge_dict['seg_to_syn'].keys()
        self.segments.sort()

    def next_segment(self):
        """Returns next synapse ID in list of synapses"""
        self.index += 1
        self.set_segment(self.segments[self.index])
        return self.segment

    def prev_segment(self):
        """Returns previous synapse ID in list of synapses"""
        self.index -= 1
        self.set_segment(self.segments[self.index])
        return self.segment

    def set_segment(self, seg_id):
        """Create Segment object on seg_id"""
        if seg_id in self.segments:
            print('set segment to ' + str(seg_id))
            self.segment = Segment(self.edge_dict, seg_id)
            self.index = self.segments.index(seg_id)
            print(str(self.index) + ' / ' + str(len(self.segments)))
            print(str(self.segment))
        else:
            print(str(seg_id) + " not in segment list")

    def get_segment_id(self):
        return self.segment.seg_id

    def get_synapse_coords(self, synapses):
        """Get list of synapse coords given a list of synapse IDs
        """
        coords = []
        for s in synapses:
            coords.append(list(self.edge_dict['syn_coords'][s]))
        return coords

    def get_synapses(self):
        """Get coords of current segment's synapses
        """
        return self.segment.get_synapses()

    def get_synapses_by_label(self, label):
        """Get current segment's synapses by label
        """
        return self.segment.get_synapses_by_label(label)

    def get_synapses_by_neighbor_label(self, label):
        return self.segment.get_synapses_by_neighbor_label(label)

    def get_segments_from_synapses(self, synapses):
        """Given set of synapses, return list of attached segments
        **Assumes that all synapses are with the current segment
        """
        k = 1 if self.segment.prepost == 0 else 0
        segments = []
        for syn in synapses:
            segments.append(self.edge_dict['syn_to_segs'][syn][k])
        return segments

    def get_neighbors(self):
        """Get neighbors of current segment
        """
        return self.segment.get_neighbors()

    def get_neighbors_by_label(self, label):
        """Get neighbors of current segment by label
        """
        return self.segment.get_neighbors_by_label(label)

    def count_elements(self, collection):
        return Counter(collection)

    def get_common_segs(self, segments):
        common_segs = {}
        for seg in segments:
            neighbors = self.edge_dict['seg_to_neighbors'][seg]
            for n in neighbors:
                edges.push_dict(common_segs, n, seg)
        return common_segs

    def get_shared_segs(self, common_segs, n=1):
        """Filter only common segs that have at least n shared segs
        """
        return {k:v for k,v in common_segs.iteritems() if len(v) >= n}


#Tests
if __name__ == '__main__':
    pass
