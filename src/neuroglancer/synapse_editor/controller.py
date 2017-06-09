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

assert len(sys.argv) > 2
infile = sys.argv[1]
outfile = sys.argv[2]
model = Model(infile, outfile)

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
        self.synapses = []
        self.segments = []
        self.synapses_on = True
        self.segments_on = True
        self.shared_synapses_only = True
        self.shared_segments_only = True

    def update_display(self):
        if self.segments_on:
            segs = model.get_segments()
            current_state['layers']['segmentation']['segments'] = segs
        else:
            current_state['layers']['segmentation']['segments'] = []
        if self.synapses_on:
            coords = model.get_synapses()
            current_state['layers']['synapses'] = {'type':'synapse', \
                                                            'points':coords}
        else:
            current_state['layers']['synapses'] = {'type':'synapse', \
                                                            'points':[]}
        broadcast()

    def get_segments(self):
        if 'segments' in current_state['layers']['segmentation']:
            return map(int, current_state['layers']['segmentation']['segments'])
        else:
            return []

    def set_segments(self, seg_ids):
        model.set_segments(seg_ids)
        return self.update_display()      

    def update_segments(self):
        seg_ids = self.get_segments()
        self.set_segments(seg_ids)

    def update_synapses(self):
        coords = self.get_synapses()
        model.update_synapses(coords)

    def toggle_segments(self):
        """Toggle whether segments are displayed or not
        """
        self.segments_on = 0 if self.segments_on else 1
        return self.update_display()

    def toggle_synapses(self):
        """Toggle whether segments are displayed or not
        """
        self.synapses_on = 0 if self.synapses_on else 1
        return self.update_display()        

    def save(self):
        model.write()

    def get_synapses(self):
        coords = None
        if 'synapses' in current_state['layers']:
            if 'points' in current_state['layers']['synapses']:
                synapses = current_state['layers']['synapses']['points']
                coords = [[int(round(c)) for c in coord] for coord in synapses]
        return coords

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
        global current_state
        current_state = json.JSONDecoder(object_pairs_hook=OrderedDict).decode(json_state)
        global n_messages
        if not n_messages:
            print('state initialized')
        n_messages += 1
        c.check_ng()

    def on_close(self):
        # If client disconnects, remove him from the clients list
        clients.remove(self)

    def initialize_state(self, state):
        """
        This is called once the connection is stablished
        """
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