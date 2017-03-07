import Tkinter as tk

# Create view
def create_info_labels(root, texts):
    """Create and return handles to labels in root
    Inputs:
        texts: list of strings to attach to labels
    """
    labels = [tk.Label(root, text=text) for text in texts]
    for l in labels:
        l.pack()

    return labels

def create_buttons(root, next_segment_event, prev_segment_event,
                            next_synapse_event, prev_synapse_event):
    """Create buttons to move forward/backward in synapses/segments
    Inputs:
        *_event:fn that handles button press event
    """
    segment_forward_button = tk.Button(root, text="Next Segment", command=next_segment_event)
    segment_forward_button.pack()
    segment_backward_button = tk.Button(root, text="Previous Segment", command=prev_segment_event)
    segment_backward_button.pack()
    synapse_forward_button = tk.Button(root, text="Next Synapse", command=next_synapse_event)
    synapse_forward_button.pack()
    synapse_backward_button = tk.Button(root, text="Previous Synapse", command=prev_synapse_event)
    synapse_backward_button.pack()

def create_lists(root, segments, synapses, segment_select_event, synapse_select_event):
    """Creates listbox items to display list of available segments and synapses
    corresponding to segment
    Inputs:
        segments: list of segment ids
        synapses: list of synapse ids
        *_select_event: fn that handles selection of item in list
    """
    segment_listbox = tk.Listbox(root)
    segment_listbox.bind('<Double-Button-1>',segment_select_event)
    for segment_id in segments:
        segment_listbox.insert(tk.END, str(segment_id))

    synapse_listbox = tk.Listbox(root)
    synapse_listbox.bind('<Double-Button-1>',synapse_select_event)
    for synapse_id in synapses:
        synapse_listbox.insert(tk.END, str(synapse_id))

    segment_listbox.pack()
    synapse_listbox.pack()

def create_textbox(root, synapse_classification_event, prev_synapse_event, next_synapse_event):
    """Creates textbox for user to enter classication for each synpase."""
    entry = tk.Entry(root)
    entry.bind("<Return>", synapse_classification_event)
    entry.pack()

# Fns to update View
def update_info_labels(root, labels, texts):
    """Update text and return handles to labels in root"""
    for label, text in zip(labels, texts):
        label.config(text=text)
    return labels

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

synapses = [1,2,3,4,5,6]
segments = [10,11,12,13,14,15]
root = tk.Tk()
labels = create_info_labels(root, ['a', 'b', 'c', 'd', 'e'])
labels = update_info_labels(root, labels, ['e', 'f', 'g', 'h', 'i'])
create_buttons(root, next_segment_event, prev_segment_event, next_synapse_event, prev_synapse_event)
create_lists(root, segments, synapses, segment_select_event, synapse_select_event)
create_textbox(root, synapse_classification_event, prev_synapse_event, next_synapse_event)

root.mainloop()

#segment_id_text, synapse_id_text, segments_text, synapses_text, total_synapses_text = init_text
"""
entry = tk.Entry(root)
entry.bind("<Return>", show_segment_event)
# entry.bind("<KP_Enter>", show_segment_event)
entry.bind("<KP_Enter>", show_neighbors_event)
entry.bind("<Escape>", shutdown)
entry.pack()

# Update View
def update_info_labels(root, text)
"""
