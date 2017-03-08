import Tkinter as tk
import sys
sys.path.append("/usr/people/kluther/Documents/ReconstructionEvaluations/src/neuroglancer")
from model import Model
from view import View
from ui import UI
import edges

class Controller:
    """Handles button presses and text entries, makes calls to update Tkinter ui
        and neuroglancer view and calls model to read/write segments/synapses
        and their classifications
    """
    def __init__(self, infile, outfile):
        self.model = Model(infile, outfile)
        self.view = View()
        self.ui = UI(self.next_segment_event, self.prev_segment_event, \
                self.next_synapse_event, self.prev_synapse_event, self.synapse_classification_event)
        #self.ui.start()

    def next_synapse_event(self):
        self.model.next_synapse()
        self.update_synapse()

    def prev_synapse_event(self):
        self.model.prev_synapse()
        self.update_synapse()

    def synapse_classification_event(self, evt):
        classification = self.ui.get_classification()
        self.model.classify_synapse(classification)
        self.model.next_synapse()
        self.update_synapse()

    def update_synapse(self):
        """Updates view and ui to display curren"/usr/people/kluther/Documents/data/ReconstructionEvaluations/t synapse"""
        self.view_display_synapse()

    def view_display_synapse(self):
        """Updates view to display current synapse"""
        # Get segments, location for synapse
        synapse = self.model.current_synapse
        segments = self.model.edge_dict['syn_to_segs'][synapse]
        coords = self.model.edge_dict['syn_coords'][synapse]

        # Display segments"/usr/people/kluther/Documents/data/ReconstructionEvaluations/
        self.view.clear_segments()
        for seg in segments:
            self.view.show_segment(seg)

        # Have view point at synapse
        self.view.set_voxelCoordinates(coords)

    def ui_update(self):
        """Updates UI labels to reflect current state"""
        raise NotImplementedError


    def next_segment_event(self):
        raise NotImplementedError

    def prev_segment_event(self):
        raise NotImplementedError

    def segment_select_event(evt):
        raise NotImplementedError

    def synapse_select_event(evt):
        raise NotImplementedError

    def shutdown(evt):
        raise NotImplementedError


# Test
if __name__=="__main__":
    infile = "/usr/people/kluther/Documents/data/ReconstructionEvaluations/170303_tm_synapse_semantics_filtered_edges.csv"
    outfile = "/usr/people/kluther/Documents/data/ReconstructionEvaluations/junk.csv"
    c = Controller(infile, outfile)
    import pdb; pdb.set_trace()

"""
        #UI
        num_classified = self.model.num_classified
        self.model.num_synapses

        self.ui.update_info_labels()"""

"""
    def next_segment_event(self):
        segment = self.model.next_segment()
        self._show_segment(segment)

    def prev_segment_event(self):
        segment = self.model.prev_segment()
        self._show_segment(segment)

    def segment_select_event(evt):
        print("seg selected")

    def synapse_select_event(evt):
        print("syn selected")

    def shutdown(evt):
        print("shutdown")
"""
