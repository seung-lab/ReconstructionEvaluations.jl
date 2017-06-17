import sys
from os.path import expanduser, join

import threading
from tornado import web, ioloop, httpserver
from sockjs.tornado import SockJSConnection, SockJSRouter
import json
from collections import OrderedDict

url = "https://neuromancer-seung-import.appspot.com/#!{'layers':{'image':{'type':'image'_'source':'precomputed://glance://s1_v0/image'}_'segmentation':{'type':'segmentation'_'source':'precomputed://glance://s1_v0/segmentation_0.2'_'selectedAlpha':0.44}}_'navigation':{'pose':{'position':{'voxelSize':[6_6_30]_'voxelCoordinates':[7648.091796875_4767.28564453125_1267.79638671875]}}_'zoomFactor':2.7094874095355532}_'layout':'xy-3d'_'perspectiveOrientation':[-0.4056483507156372_-0.5968747735023499_-0.42320775985717773_0.5478002429008484]_'perspectiveZoom':443.6340451771268_'showSlices':false_'stateURL':'https://localhost:9999'}"
print(url)

# need to run controller from ReconstructionEvaluations/src/neuroglancer
sys.path.append("../neuroglancer")
from model import Model
from ui import UI
import edges

clients = set()
n_messages = 0
current_state = None
receiving_message = False

assert len(sys.argv) > 3
edges_fn = sys.argv[1]
seg_label_fn = sys.argv[2]
syn_label_fn = sys.argv[3]
model = Model(edges_fn, seg_label_fn, syn_label_fn)

# In order for the webbrowser to connect to this server
# add to the url 'stateURL':'http://localhost:9999'
def broadcast():
    """
    Use this method to broadcast a new state to all connected clients.
    Without the need to wait for an `on_state_change`.
    """
    # global receiving_message
    # if not receiving_message:
    router.broadcast(clients.copy(), json.dumps(current_state))

class Controller:
    """Handles button presses and text entries, makes calls to update Tkinter ui
        and neuroglancer view and calls model to read/write segments/synapses
        and their classifications
    """
    def __init__(self, headless=True):

        self.synapses = []
        self.segments_on = 0
        self.synapse_label_switch = {}
        for k in model.edge_dict['label_to_syn'].keys():
            self.synapse_label_switch[k] = 1
        self.segment_label_switch = {}
        for k in model.edge_dict['label_to_segs'].keys():
            self.segment_label_switch[k] = 1
        if not headless:
            self.ui = UI(self.next_segment, self.prev_segment, \
                        self.segment_select, self.toggle_segments, \
                        self.toggle_spines, self.toggle_shafts, \
                        self.toggle_seg_label_1, \
                        self.toggle_seg_label_2, \
                        self.toggle_seg_label_3, \
                        self.toggle_seg_label_4)
            self.ui.start()

    def update_display(self):
        syn = self.update_synapses()
        segs = self.update_segments()
        broadcast()
        return syn, segs

    def set_segment(self, seg_id):
        model.set_segment(seg_id)
        return self.update_display()

    def segment_select(self, event):
        seg_id = self.ui.get_segment_id()
        model.set_segment(seg_id)
        self.ui.set_segment_id(seg_id)
        self.update_display()

    def update_synapses(self):
        syn_label = set()
        syn_segs = set()
        for k,v in self.synapse_label_switch.iteritems():
            if v == 1:
                syn_label = syn_label.union(model.get_synapses_by_label(k)) 
        for k,v in self.segment_label_switch.iteritems():
            if v == 1:
                syn_segs = syn_segs.union(model.get_synapses_by_neighbor_label(k))
        self.synapses = list(syn_label & syn_segs)
        coords = model.get_synapse_coords(self.synapses)
        self.set_coords(coords)
        return self.synapses

    def get_segments(self):
        if 'segments' in current_state['layers']['segmentation']:
            return map(int, current_state['layers']['segmentation']['segments'])
        else:
            return []

    def display_coords(self, coords):
        self.set_coords(coords)
        broadcast()

    def display_segments(self, segments):
        self.set_segments(segments)
        broadcast()

    def set_coords(self, coords):
        current_state['layers']['synapses'] = {'type':'point', \
                                                        'points':coords}

    def set_segments(self, segs):
        current_state['layers']['segmentation']['segments'] = segs

    def update_segments(self):
        segments = [model.get_segment_id()]
        if self.segments_on:
            segments.extend(model.get_segments_from_synapses(self.synapses))
        self.set_segments(segments)
        return segments

    def toggle_segments(self):
        """Toggle whether segments are displayed or not
        """
        self.segments_on = 0 if self.segments_on else 1
        return self.update_display()

    def toggle_synapse_label(self, label):
        """Toggle display of synapses with label
        """
        switch = self.synapse_label_switch[label]
        self.synapse_label_switch[label] = 0 if switch == 1 else 1
        return self.update_display()

    def toggle_segment_label(self, label):
        """Toggle display of segments with label
        """
        switch = self.segment_label_switch[label]
        self.segment_label_switch[label] = 0 if switch == 1 else 1
        return self.update_display()

    def set_voxelCoordinates(self, new_pos):
        """Set the voxelCoordinates to the numpy list"""
        current_state['navigation']['pose']['position']['voxelCoordinates'] = new_pos
        
    # def next_segment(self):
    #     seg_id = model.next_segment()
    #     self.display_segment(seg_id)

    # def prev_segment(self):
    #     seg_id = model.prev_segment()
    #     self.display_segment(seg_id)

    def synapse_select(evt):
        raise NotImplementedError

    def shutdown(evt):
        raise NotImplementedError

# websockets connections
class Connection(SockJSConnection):
    def on_open(self, info):
        """
        info is an object which contains caller IP address, query string
        parameters and cookies associated with this request"""
        # When new client comes in, will add it to the clients list
        clients.add(self)

    def on_message(self, json_state):
        """
        This will call initialize_state or on_state_change depening on if it is
        the first message recieved.
        """
        global receiving_message
        receiving_message = True
        global current_state
        current_state = json.JSONDecoder(object_pairs_hook=OrderedDict).decode(json_state)
        global n_messages

        if not n_messages: #first message ever
            new_state = self.initialize_state(current_state)
        else:
            new_state = self.on_state_change(current_state)

        n_messages += 1
        if new_state: #if you return a new state send it back
            receiving_message = False


    def on_close(self):
        # If client disconnects, remove him from the clients list
        clients.remove(self)

    def initialize_state(self, state):
        """
        This is called once the connection is stablished
        """
        print 'state initialized'
        return state

    def on_state_change(self, state):
        """
        This is called every time there is a new state available
        (except the very first time).
        """
        return state


# Tornado & Tk need to run on separate threads
class TornadoThread(threading.Thread):
    def __init__(self):
        # super(TornadoThread, self).__init__()
        # self._stop = threading.Event()
        threading.Thread.__init__(self)
        self.daemon = True

        socketApp = web.Application(router.urls)
        http_server = httpserver.HTTPServer(socketApp, ssl_options={
            "certfile": "./certificate.crt",
            "keyfile": "./privateKey.key",
        })
        http_server.bind(9999) #port
        http_server.start(1)

    def run(self):
        print("IOLoop starting")
        ioloop.IOLoop.instance().start()


router = SockJSRouter(Connection)
TornadoThread = TornadoThread()
TornadoThread.start()
c = Controller()