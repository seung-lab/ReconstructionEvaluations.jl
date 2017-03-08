import Tkinter as tk


class Controller:
    """Handles button presses and text entries, makes calls to update Tkinter ui
        and neuroglancer view and calls model to read/write segments/synapses
        and their classifications
    """
    def __init__(self, infile, outfile):
        self.model = Model(infile, outfile)
        self.ui = UI(self.next_segment_event, self.prev_segment_event, \
                self.next_synapse_event, self.prev_synapse_event, self.synapse_classification_event )
        self.view = View()


    def next_synapse_event(self):
        self.model.next_synapse()
        self.update()

    def prev_synapse_event(self):
        self.model.prev_synapse()
        self.update()

    def synapse_classification_event(self, evt):
        classification = self._get_classification(evt)
        self.model.classify_synapse(classification)
        self.model.next_synapse()
        self.update()

    def update(self):
        """Updates view and model to reflect current state in model"""
        #View

        #UI
        num_classified = self.model.num_classified
        self.model.num_synapses

        self.ui.update_info_labels()

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
