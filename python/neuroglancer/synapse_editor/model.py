from edges import Edges
import copy
import h5py
import numpy as np
from operator import or_

class Segment(object):

    def __init__(self, edges, seg_id=0):
        """Segment object loads relevant information for specifc segment
        """
        self.id = seg_id
    
        self.pre_neighbors = edges.pre_to_post.get(seg_id, [])
        self.post_neighbors = edges.post_to_pre.get(seg_id, [])
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
            edges: Edges object with all edge dictionaries

            synapses: list of current synapses to be displayed
            synapse_idx: index of current synapse
            synapse_classifications: dict of synapse labelings
            segments: list of segments to be displayed
            current_segment: ID of segment being viewed
            segment_idx: index of current segment
        """
        self.edges = Edges(src_file, dst_file)
        self.segments = []
        self.synapses = {'pre': [], 'post': [], 'shared': []}
        self.coords = {'pre': [], 'post': [], 'shared': []}
        self.neighbors = {'pre': [], 'post': [], 'shared': []}

    def set_segments(self, seg_ids):
        self.segments = [Segment(self.edges, seg_id) for seg_id in seg_ids]
        self.load_synapses()
        self.load_neighbors()
        print(self)

    def load_synapses(self):
        pre_synapses = []
        post_synapses = []
        shared_synapses = []
        for seg in self.segments:
            pre_synapses.append(set(seg.get_synapses('pre')))
            post_synapses.append(set(seg.get_synapses('post')))
        for i, pre in enumerate(pre_synapses):
            for j, post in enumerate(post_synapses):
                if i != j:
                    shared_synapses.append(pre & post)
        self.synapses['pre'] = list(reduce(or_, pre_synapses, set()))
        self.synapses['post'] = list(reduce(or_, post_synapses, set()))
        self.synapses['shared'] = list(reduce(or_, shared_synapses, set()))
        self.load_centroids()

    def load_centroids(self):
        for k, syn in self.synapses.items():
            coords = []
            for syn in self.synapses[k]:
                coords.append(self.edges.syn_coords[syn])
            self.coords[k] = coords

    # def load_pre_post_centroids(self):
    #     coords = []
    #     for syn in self.synapses:
    #         coords.append(self.edges.syn_coords_pre_post[syn])
    #     self.coords = coords

    def load_neighbors(self):
        pre_neighbors = []
        post_neighbors = []
        shared_neighbors = []
        for seg in self.segments:
            pre_neighbors.append(set(seg.get_neighbors('pre')))
            post_neighbors.append(set(seg.get_neighbors('post')))
        for i, pre in enumerate(pre_neighbors):
            for j, post in enumerate(post_neighbors):
                if i != j:
                    shared_neighbors.append(pre & post)
        self.neighbors['pre'] = list(reduce(or_, pre_neighbors, set()))
        self.neighbors['post'] = list(reduce(or_, post_neighbors, set()))
        self.neighbors['shared'] = list(reduce(or_, shared_neighbors, set()))

    def get_synapses(self, k='all'):
        if k not in self.synapses.keys():
            return self.synapses['pre'] + self.synapses['post']
        else:
            return self.synapses[k]

    def get_coords(self, k='all'):
        if k not in self.coords.keys():
            return self.coords['pre'] + self.coords['post']
        else:
            return self.coords[k]

    def get_neighbors(self, k='all'):
        if k not in self.neighbors.keys():
            return self.neighbors['pre'] + self.neighbors['post']
        else:
            return self.neighbors[k]

    def get_segments(self, k, neighbors=False):
        segs = [seg.id for seg in self.segments]
        if neighbors:
            segs += self.get_neighbors(k)
        return segs

    def get_seg_value(self, coord):
        """Lookup coordinate in the segmentation H5 file
        """
        f = h5py.File(self.segmentation_file, "r")
        dset = f['/main']
        return int(dset[tuple(coord)])

    def add_edge(self, pre, post, centroid):
        self.edges.add_edge(pre, post, centroid, centroid)

    def update_synapses(self, k, new_coords):
        """Update the edge dicts based on the list of new synapse coords

        Run through current coords and the working list, tabulating which need
        to be removed from the current list, and what needs to be added from
        the working list.

        Then run through the "to add" and "to remove" lists, making the 
        adjustments to the edge dicts.
        """
        old_coords = self.get_coords(k)
        old_synapses = self.get_synapses(k)
        syn_to_remove = np.ones(len(old_synapses), dtype=bool)
        syn_to_add = np.ones(len(new_coords), dtype=bool)

        for i, old_coord in enumerate(old_coords):
            for j, new_coord in enumerate(new_coords):
                if old_coord == new_coord:
                    syn_to_remove[i] = False
                    syn_to_add[j] = False

        for syn in np.array(old_synapses)[syn_to_remove]:
            self.edges.remove_edge(syn)

        if sum(syn_to_add) > 0:
            print('There are new synapses. Use model.add_edge() ' + 
                'to manually add them.')

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

    def undo(self):
        self.edges.undo()

    def save(self):
        """Write update edges csv to outfile
        """
        self.edges.save()

    def __repr__(self):
        s  = 'no\tsyn\tcentroid\t\tpre\t\tpost\n'
        syn_coord = zip(self.get_synapses(), self.get_coords())
        for i, (syn, coord) in enumerate(syn_coord):
            pre = self.edges.syn_to_pre_seg[syn]
            post = self.edges.syn_to_post_seg[syn]
            s += str(i) + '\t' 
            s += str(syn) + '\t' 
            s += str(coord) + '\t'
            s += str(pre) + '\t'
            s += str(post) + '\t'
            s += '\n'
        return s
