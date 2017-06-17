import Tkinter as tk

# Create ui
class UI(object):
    def __init__(self, next_segment_event, prev_segment_event, 
                        segment_select_event, toggle_segments_event,
                        toggle_spines_event, toggle_shafts_event, 
                        toggle_seg_label_1_event, toggle_seg_label_2_event,
                        toggle_seg_label_3_event, toggle_seg_label_4_event):
        self.root = tk.Tk()
        self.root.bind("<Escape>", self.shutdown)
        self.root.title("NG State")
        self.show_synapses = tk.IntVar()
        # self.create_synapse_toggle()
        # self.create_info_labels()
        # self.create_buttons(next_segment_event, prev_segment_event)
        #self.create_lists()
        # self.classification_entry = self.create_textbox(synapse_classification_event, "class")
        self.seg_id = tk.StringVar()
        self.seg_id.set("")

        self.segments_on = tk.IntVar()
        self.segments_checkbox = tk.Checkbutton(self.root, text="segments", 
                        variable=self.segments_on, command=toggle_segments_event)
        self.segments_checkbox.pack()

        self.shafts_on = tk.IntVar()
        self.spines_on = tk.IntVar()
        self.shaft_checkbox = tk.Checkbutton(self.root, text="shaft", 
                        variable=self.shafts_on, command=toggle_shafts_event)
        self.spine_checkbox = tk.Checkbutton(self.root, text="spine", 
                        variable=self.spines_on, command=toggle_spines_event)
        self.shaft_checkbox.pack()
        self.spine_checkbox.pack()

        self.seg_label_1 = tk.IntVar()
        self.seg_label_2 = tk.IntVar()
        self.seg_label_3 = tk.IntVar()
        self.seg_label_4 = tk.IntVar()

        self.seg_label_1_checkbox = tk.Checkbutton(self.root, text="seg label 1", 
                        variable=self.seg_label_1, command=toggle_seg_label_1_event)
        self.seg_label_2_checkbox = tk.Checkbutton(self.root, text="seg label 2", 
                        variable=self.seg_label_2, command=toggle_seg_label_2_event)
        self.seg_label_3_checkbox = tk.Checkbutton(self.root, text="seg label 3", 
                        variable=self.seg_label_3, command=toggle_seg_label_3_event)
        self.seg_label_4_checkbox = tk.Checkbutton(self.root, text="seg label 4", 
                        variable=self.seg_label_4, command=toggle_seg_label_4_event)
        self.seg_label_1_checkbox.pack()
        self.seg_label_2_checkbox.pack()
        self.seg_label_3_checkbox.pack()
        self.seg_label_4_checkbox.pack()

        self.shafts_on.set(1)
        self.spines_on.set(1)
        self.seg_label_1.set(1)
        self.seg_label_2.set(1)
        self.seg_label_3.set(1)
        self.seg_label_4.set(1)

        self.segment_id_entry = self.create_textbox(segment_select_event, self.seg_id, "seg_id")

    def start(self):
        self.root.mainloop()

    def get_segments_on(self):
        return self.segments_on.get()

    def get_shafts_on(self):
        return self.shafts_on.get()
    
    def get_spines_on(self):
        return self.spines_on.get()

    def get_seg_label_1(self):
        return self.seg_label_1.get()

    def get_seg_label_2(self):
        return self.seg_label_2.get()

    def get_seg_label_3(self):
        return self.seg_label_3.get()

    def get_seg_label_4(self):
        return self.seg_label_4.get()

    def create_info_labels(self):
        """Create and return handles to labels in root"""
        label_names = ['a', 'b', 'c', 'd', 'e']
        labels = [tk.Label(self.root, text=text) for text in label_names]
        for l in labels:
            l.pack()

        self.labels = labels

    def create_buttons(self, next_segment_event, prev_segment_event):
        """Create buttons to move forward/backward in synapses/segments
        Inputs:
            *_event:fn that handles button press event
        """
        segment_forward_button = tk.Button(self.root, text="Next Segment", command=next_segment_event)
        segment_forward_button.pack(side=tk.LEFT)
        segment_backward_button = tk.Button(self.root, text="Previous Segment", command=prev_segment_event)
        segment_backward_button.pack(side=tk.RIGHT)

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
