import Tkinter as tk

# Create ui
class UI(object):
    def __init__(self, next_segment_event, prev_segment_event, next_synapse_event, prev_synapse_event, synapse_classification_event):
        self.create_info_labels(texts)
        self.create_buttons(next_segment_event, prev_segment_event, next_synapse_event, prev_synapse_event)
        #self.create_lists()
        self.create_textbox(synapse_classification_event, next_synapse_event, prev_synapse_event)

    def create_info_labels(self, texts):
        """Create and return handles to labels in root
        Inputs:
            texts: list of strings to attach to labels
        """
        labels = [tk.Label(self.root, text=text) for text in texts]
        for l in labels:
            l.pack()

        self.labels = labels

    def create_buttons(self, next_segment_event, prev_segment_event,
                            next_synapse_event, prev_synapse_event):
        """Create buttons to move forward/backward in synapses/segments
        Inputs:
            *_event:fn that handles button press event
        """
        segment_forward_button = tk.Button(self.root, text="Next Segment", command=next_segment_event)
        segment_forward_button.pack()
        segment_backward_button = tk.Button(self.root, text="Previous Segment", command=prev_segment_event)
        segment_backward_button.pack()
        synapse_forward_button = tk.Button(self.root, text="Next Synapse", command=next_synapse_event)
        synapse_forward_button.pack()
        synapse_backward_button = tk.Button(self.root, text="Previous Synapse", command=prev_synapse_event)
        synapse_backward_button.pack()

    def create_lists(self, segments, synapses, segment_select_event, synapse_select_event):
        """Creates listbox items to display list of available segments and synapses
        corresponding to segment
        Inputs:
            segments: list of segment ids
            synapses: list of synapse ids
            *_select_event: fn that handles selection of item in list
        """
        segment_listbox = tk.Listbox(self.root)
        segment_listbox.bind('<Double-Button-1>',segment_select_event)
        for segment_id in segments:
            segment_listbox.insert(tk.END, str(segment_id))

        synapse_listbox = tk.Listbox(self.root)
        synapse_listbox.bind('<Double-Button-1>',synapse_select_event)
        for synapse_id in synapses:
            synapse_listbox.insert(tk.END, str(synapse_id))

        segment_listbox.pack()
        synapse_listbox.pack()

    def create_textbox(self, synapse_classification_event, prev_synapse_event, next_synapse_event):
        """Creates textbox for user to enter classication for each synpase."""
        entry = tk.Entry(self.root)
        entry.bind("<Return>", synapse_classification_event)
        entry.bind("<Escape>", shutdown)
        entry.pack()

    # Fns to update ui
    def update_info_labels(self, labels, texts):
        """Update text and return handles to labels in root"""
        for label, text in zip(self.labels, texts):
            label.config(text=text)

    def update_listboxes(self, segment_listbox, synapse_listbox):
        pass

# Testing
class G:
    def __init__(self, model):
        self.model=model
    def next_synapse_event(self):
        print("next syn")

g = G('model')

def next_synapse_event():
    print("next syn")

def prev_synapse_event():
    print("prev syn")

def next_segment_event():
    print("next seg")

def prev_segment_event():
    print("prev seg")

def segment_select_event(evt):
    print("seg selected")

def synapse_select_event(evt):
    print("syn selected")

def synapse_classification_event(evt):
    print("syn class")

def shutdown(evt):
    print("shutdown")

if __name__=="__main__":
    synapses = [1,2,3,4,5,6]
    segments = [10,11,12,13,14,15]
    root = tk.Tk()
    labels = create_info_labels(root, ['a', 'b', 'c', 'd', 'e'])
    labels = update_info_labels(root, labels, ['e', 'f', 'g', 'h', 'i'])
    create_buttons(root, next_segment_event, prev_segment_event, g.next_synapse_event, prev_synapse_event)
    create_lists(root, segments, synapses, segment_select_event, synapse_select_event)
    create_textbox(root, synapse_classification_event, prev_synapse_event, next_synapse_event)

    root.mainloop()

#segment_id_text, synapse_id_text, segments_text, synapses_text, total_synapses_text = init_text
