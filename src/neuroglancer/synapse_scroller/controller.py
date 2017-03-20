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
infile = sys.argv[1]
outfile = sys.argv[2]
segmentation_file = sys.argv[3]
model = Model(infile, outfile, segmentation_file)

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
                self.next_synapse_event, self.prev_synapse_event, \
                self.synapse_classification_event, self.segment_select_event, \
                self.save_synapses_event)
        self.ui.start()

    def save_synapses_event(self):
        state_synapses = self.get_state_synapses()
        if state_synapses is not None:
            model.update_dicts(state_synapses)
            model.write_data()

    def next_synapse_event(self):
        model.next_synapse()
        self.update_synapse()

    def prev_synapse_event(self):
        model.prev_synapse()
        self.update_synapse()

    def synapse_classification_event(self, event):
        classification = self.ui.get_classification()
        model.classify_synapse(classification)
        model.next_synapse()
        self.update_synapse()

    def update_synapse(self):
        """Updates view and ui to display curren"/usr/people/kluther/Documents/data/ReconstructionEvaluations/synapse"""
        self.view_display_synapse()

    def segment_select_event(self, event):
        seg_id = self.ui.get_segment_id()
        model.set_segment(seg_id)
        self.display_segment(seg_id)

    def display_segment(self, seg_id):
        self.show_segment(seg_id)
        self.ui.set_segment_id(seg_id)
        self.display_synapses()

    def display_synapses(self):
        model.load_synapses()
        synapses_coords = model.get_synapse_coordinates()
        self.show_synapses(synapses_coords)
        broadcast()

    def view_display_synapse(self):
        """Updates view to display current synapse"""
        # Get segments, location for synapse
        synapse = model.current_synapse
        segments = model.edge_dict['syn_to_segs'][synapse]
        coords = model.edge_dict['syn_coords'][synapse]

        # Display segments"/usr/people/kluther/Documents/data/ReconstructionEvaluations/
        self.clear_segments()
        for seg in segments:
            self.show_segment(seg)

    def get_state_synapses(self):
        if 'synapses' in current_state['layers']:
            if 'points' in current_state['layers']['synapses']:
                synapses = current_state['layers']['synapses']['points']
                return [[int(round(c)) for c in coord] for coord in synapses]
            else:
                return None
        else:
            return None

    def show_segment(self, seg_id, hold_on=False):
        """Updates current_state to show a different segment"""
        print 'show segment ' + str(seg_id)
        if hold_on:
            if 'synapses' in current_state['layers']:
                seg_ids = current_state['layers']['segmentation']['segments'];
                seg_ids.extend(seg_id)
                current_state['layers']['segmentation']['segments'] = seg_ids
            else:
                current_state['layers']['segmentation']['segments'] = [seg_id]
        else:
            current_state['layers']['segmentation']['segments'] = [seg_id]

    def clear_segments(self):
        """Updates current_state to unselect all segments"""
        current_state['layers']['segmentation']['segments'] = []

    def set_voxelCoordinates(self, new_pos):
        """Set the voxelCoordinates to the numpy list"""
        current_state['navigation']['pose']['position']['voxelCoordinates'] = new_pos

    def show_synapses(self, coords, hold_on=False):
        """Updates state to label all synapse coords"""
        current_state['layers']['synapses'] = {'type':'synapse', \
                                                        'points':coords}
        self.set_voxelCoordinates(coords[0])
        
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