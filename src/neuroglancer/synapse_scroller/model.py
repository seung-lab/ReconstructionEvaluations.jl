import edges

class Model(object):

    def __init__(self, infile, outfile):
        self.edge_dict = {}
        self.synapse_ids = []
        self.synapse_classifications = {}
        self.synapse_idx = 0

        self.read_data(infile)
        self.create_synapse_list()

    def read_data(self, filename):
        """Reads data from csv file, filename, and processes it into dict
        """
        edge_dicts = edges.create_edge_dicts(edges.load_edges(filename))
        items = ['syn_to_segs', 'segs_to_syn', 'syn_coords', 'syn_size', \
                    'seg_to_syn', 'pre_to_post', 'post_to_pre']
        self.edge_dict = dict(rel for rel in zip(items, edge_dicts))

    def create_synapse_list(self):
        """Creates a list of unique synapses in edge_dict"""
        self.synapse_ids = self.edge_dict['syn_coords'].keys()

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
    def num_classified(self):
        return len(synapse_classifications)

    @property
    def num_synapses(self):
        return len(synapse_ids)

    @property
    def current_synapse(self):
        """Returns synapse ID of current synapse"""
        #TODO: raise an error if idx out of bounds
        return self.synapse_ids[self.synapse_idx]

#Tests
if __name__ == '__main__':
    infile = "/Users/kyleluther/Documents/Research/SeungLab/data/ReconstructionEvaluations/170303_tm_synapse_semantics_filtered_edges.csv"
    outfile = "junk.csv"
    m = Model(infile, outfile)
    import pdb; pdb.set_trace()
    print m.current_synapse, m.next_synapse(), m.prev_synapse()
    m.classify_synapse(3)
    print m.synapse_classifications
