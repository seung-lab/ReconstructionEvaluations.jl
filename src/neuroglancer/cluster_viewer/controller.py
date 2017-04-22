import sys
from os.path import expanduser, join

import threading
from tornado import web, ioloop, httpserver
from sockjs.tornado import SockJSConnection, SockJSRouter
import json
from collections import OrderedDict

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
    def __init__(self):
        self.ui = UI(self.next_segment_event, self.prev_segment_event, \
                        self.segment_select_event, self.toggle_segments_event, \
                        self.toggle_spines_event, self.toggle_shafts_event, \
                        self.toggle_seg_label_1_event, \
                        self.toggle_seg_label_2_event, \
                        self.toggle_seg_label_3_event, \
                        self.toggle_seg_label_4_event)
        self.synapses = []
        self.segments_on = 0
        self.shafts_on = 1
        self.spines_on = 1
        self.seg_label_1_on = 1
        self.seg_label_2_on = 1
        self.seg_label_3_on = 1
        self.seg_label_4_on = 1
        self.ui.start()

    def update_display(self):
        self.update_synapses()
        self.update_segments()
        broadcast()

    def segment_select_event(self, event):
        seg_id = self.ui.get_segment_id()
        model.set_segment(seg_id)
        self.display_segment(seg_id)

    def display_segment(self, seg_id):
        self.ui.set_segment_id(seg_id)
        self.update_display()

    def update_synapses(self):
        shaft_spine = set()
        seg_labels = set()
        if self.shafts_on == 1:
            shaft_spine = shaft_spine.union(model.get_synapses_by_label(0))
        if self.spines_on == 1:
            shaft_spine = shaft_spine.union(model.get_synapses_by_label(1))
        if self.seg_label_1_on == 1:
            seg_labels = seg_labels.union(model.get_synapses_by_neighbor_label(1))
        if self.seg_label_2_on == 1:
            seg_labels = seg_labels.union(model.get_synapses_by_neighbor_label(2))
        if self.seg_label_3_on == 1:
            seg_labels = seg_labels.union(model.get_synapses_by_neighbor_label(3))
        if self.seg_label_4_on == 1:
            seg_labels = seg_labels.union(model.get_synapses_by_neighbor_label(4))
        self.synapses = list(shaft_spine & seg_labels)
        coords = model.get_synapse_coords(self.synapses)
        current_state['layers']['synapses'] = {'type':'point', \
                                                        'points':coords}

    def update_segments(self):
        segments = [model.get_segment_id()]
        if self.segments_on:
            segments.extend(model.get_segments_from_synapses(self.synapses))
            print(segments)
        current_state['layers']['segmentation']['segments'] = segments

    def toggle_segments_event(self):
        self.segments_on = self.ui.get_segments_on()
        self.update_display()

    def toggle_shafts_event(self):
        self.shafts_on = self.ui.get_shafts_on()
        self.update_display()

    def toggle_spines_event(self):
        self.spines_on = self.ui.get_spines_on()
        self.update_display()

    def toggle_seg_label_1_event(self):
        self.seg_label_1_on = self.ui.get_seg_label_1()
        self.update_display()

    def toggle_seg_label_2_event(self):
        self.seg_label_2_on = self.ui.get_seg_label_2()
        self.update_display()

    def toggle_seg_label_3_event(self):
        self.seg_label_3_on = self.ui.get_seg_label_3()
        self.update_display()

    def toggle_seg_label_4_event(self):
        self.seg_label_4_on = self.ui.get_seg_label_4()
        self.update_display()

    def set_voxelCoordinates(self, new_pos):
        """Set the voxelCoordinates to the numpy list"""
        current_state['navigation']['pose']['position']['voxelCoordinates'] = new_pos
        
    def next_segment_event(self):
        seg_id = model.next_segment()
        self.display_segment(seg_id)

    def prev_segment_event(self):
        seg_id = model.prev_segment()
        self.display_segment(seg_id)

    def synapse_select_event(evt):
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