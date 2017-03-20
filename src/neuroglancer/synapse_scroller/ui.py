import Tkinter as tk

# Create ui
class UI(object):
    def __init__(self, next_segment_event, prev_segment_event, 
                        next_synapse_event, prev_synapse_event, 
                        synapse_classification_event, segment_select_event, 
                        save_synapses_event):
        self.root = tk.Tk()
        self.root.bind("<Escape>", self.shutdown)
        self.root.title("NG State")
        self.show_synapses = tk.IntVar()
        # self.create_synapse_toggle()
        # self.create_info_labels()
        self.create_buttons(next_segment_event, prev_segment_event, 
                            next_synapse_event, prev_synapse_event, 
                            save_synapses_event)
        #self.create_lists()
        # self.classification_entry = self.create_textbox(synapse_classification_event, "class")
        self.seg_id = tk.StringVar()
        self.seg_id.set("")
        self.segment_id_entry = self.create_textbox(segment_select_event, self.seg_id, "seg_id")

    def start(self):
        self.root.mainloop()

    def create_info_labels(self):
        """Create and return handles to labels in root"""
        label_names = ['a', 'b', 'c', 'd', 'e']
        labels = [tk.Label(self.root, text=text) for text in label_names]
        for l in labels:
            l.pack()

        self.labels = labels

    def create_buttons(self, next_segment_event, prev_segment_event,
                            next_synapse_event, prev_synapse_event, 
                            save_synapses_event):
        """Create buttons to move forward/backward in synapses/segments
        Inputs:
            *_event:fn that handles button press event
        """
        segment_forward_button = tk.Button(self.root, text="Next Segment", command=next_segment_event)
        segment_forward_button.pack()
        segment_backward_button = tk.Button(self.root, text="Previous Segment", command=prev_segment_event)
        segment_backward_button.pack()
        # synapse_forward_button = tk.Button(self.root, text="Next Synapse", command=next_synapse_event)
        # synapse_forward_button.pack()
        # synapse_backward_button = tk.Button(self.root, text="Previous Synapse", command=prev_synapse_event)
        # synapse_backward_button.pack()
        synapse_backward_button = tk.Button(self.root, text="Save Edges", command=save_synapses_event)
        synapse_backward_button.pack()

    def synapses_on(self):
        print self.show_synapses.get()
        return self.show_synapses.get()

    def create_synapse_toggle(self):
        """Create synapse toggle button
        """
        toggle_btn = tk.Checkbutton(self.root, text='synapses', # relief="sunken", 
                        variable=self.show_synapses, command=self.synapses_on)
        toggle_btn.pack()
        return toggle_btn

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

    def create_textbox(self, action, textvar, caption=""):
        """Creates textbox that will execute action when enter is pressed.
        """
        label = tk.Label(self.root, text=caption).pack(side=tk.LEFT)
        entry = tk.Entry(self.root, textvariable=textvar)
        entry.bind("<Return>", action)
        entry.pack(side=tk.LEFT)
        return entry

    # Fns to update ui
    def update_info_labels(self, labels, texts):
        """Update text and return handles to labels in root"""
        for label, text in zip(self.labels, texts):
            label.config(text=text)

    def update_listboxes(self, segment_listbox, synapse_listbox):
        pass

    # UI state information
    def get_classification(self):
        """Returns class entered by user in classification_entry widget"""
        classification = self.classification_entry.get()
        assert(classification in ['1','2','3'])
        return classification

    def get_segment_id(self):
        try:
            seg_id = int(self.segment_id_entry.get())
            return seg_id
        except e:
            print e
            pass

    def set_segment_id(self, id):
        try:
            self.seg_id.set(str(id))
        except:
            print 'error setting seg id'
            pass

    def shutdown(self, event):
        self.root.destroy()
