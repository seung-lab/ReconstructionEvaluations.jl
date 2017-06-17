"""
T Macrina
170605

Neuroglancer-based proofreading tool for mergers

1. Run IPython interpreter
2. Run script: `%run proofread_mergers.py [STORAGE_DIR]`
    where [STORAGE_DIR] is the location of the folder where results
    should be written and read.
3. Copy in the neuroglancer link.
4. Wait for state to sync. Any equivalences from the STORAGE_DIR will be loaded.
6. In neuroglancer, use 'm' to merge selected segments (set equivalence).
7. Use `c.save()` to copy ng equivalences to state & write to STORAGE_DIR.
"""

import sys
import os
from os.path import expanduser, join, exists

import threading
from tornado import web, ioloop, httpserver
from sockjs.tornado import SockJSConnection, SockJSRouter
import json
from collections import OrderedDict

# url = "https://neuromancer-seung-import.appspot.com/#!{'layers':{'image':{'type':'image'_'source':'precomputed://gs://neuroglancer/pinky40_v11/image'}_'segmentation':{'type':'segmentation'_'source':'precomputed://gs://neuroglancer/pinky40_v11/watershed_mst_smc_sem5_remap'_'selectedAlpha':0.52}}_'navigation':{'pose':{'position':{'voxelSize':[4_4_40]_'voxelCoordinates':[44434.7890625_28642.59375_972.2528076171875]}}_'zoomFactor':11.026660708355747}_'layout':'xy-3d'_'perspectiveOrientation':[0.030826693400740623_0.08803995698690414_-0.4655480980873108_0.880092978477478]_'perspectiveZoom':653.668757757087_'showSlices':false_'stateURL':'https://localhost:9999'}"
url = "https://neuromancer-seung-import.appspot.com/#!{'layers':{'image':{'type':'image'_'source':'precomputed://gs://neuroglancer/pinky40_v11/image'}_'segmentation':{'type':'segmentation'_'source':'precomputed://gs://neuroglancer/pinky40_v11/watershed_mst_trimmed_sem_remap'}}_'navigation':{'pose':{'position':{'voxelSize':[4_4_40]_'voxelCoordinates':[17939.328125_20561.4453125_398.88970947265625]}}_'zoomFactor':4.218085215611848}_'layout':'xy-3d'_'perspectiveZoom':147.64734999660143_'perspectiveOrientation':[0.8482838273048401_0.25201889872550964_0.13395079970359802_-0.4460473656654358]_'showSlices':false_'stateURL':'https://localhost:8889'}"
print(url)

# need to run controller from ReconstructionEvaluations/src/neuroglancer
sys.path.append("../neuroglancer")

clients = set()
n_messages = 0
current_state = None

assert len(sys.argv) > 1
storage_dir = sys.argv[1]


def broadcast():
    """
    Use this method to broadcast a new state to all connected clients.
    Without the need to wait for an `on_state_change`.
    """
    router.broadcast(clients.copy(), json.dumps(current_state))

class Controller:

    def __init__(self, dirpath):
        self.dirpath = dirpath
        self.e2s_dir = join(dirpath, 'equivalences2segments')
        self.s2e_dir = join(dirpath, 'segment2equivalence')
        self.setup_dir(self.e2s_dir)
        self.setup_dir(self.s2e_dir)
        self.e2s = self.load(self.e2s_dir)

    def setup_dir(self, dirpath):
        if not exists(dirpath):
            print('Creating ' + dirpath)
            os.makedirs(dirpath)

    def load(self, dirpath, d={}):
        """Load directory into dict with filenames as key & contents as values

        Inputs:
            dirpath: string of directory path
            d: dict

        Outputs:
            Updated dict, d
        """
        for fn in os.listdir(dirpath):
            d[int(fn)] = map(int, open(os.path.join(dirpath, fn)).read().splitlines())
        return d

    def ng_has_equivalences(self):
        o = False
        if 'equivalences' in current_state['layers']['segmentation']:
            if len(current_state['layers']['segmentation']['equivalences']) > 0:
                o = True
        return o

    def check_ng(self):
        if not self.ng_has_equivalences():
            self.show()

    def set(self):
        e = []
        for equiv, segs in self.e2s.iteritems():
            e.append(map(str, segs))
        current_state['layers']['segmentation']['equivalences'] = e

    def get(self):
        return current_state['layers']['segmentation']['equivalences']

    def update(self):
        equivalences = self.get()
        for e, v in enumerate(equivalences):
            s = [int(i) for i in v]
            self.e2s[e] = s

    def show(self):
        self.set()
        broadcast()

    def write(self):
        print('Writing to ' + self.dirpath)
        for k, v in self.e2s.iteritems():
            e2s_fn = join(self.e2s_dir, str(k))
            print(str(k))
            with open(e2s_fn, 'w') as f:
                for i in v:
                    f.write(str(i)+'\n')
                    s2e_fn = join(self.s2e_dir, str(i))
                    with open(s2e_fn, 'w') as g:
                        g.write(str(k)+'\n')

    def save(self):
        self.update()
        self.write()

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
        http_server.bind(8889) #port
        http_server.start(1)

    def run(self):
        print("IOLoop starting")
        ioloop.IOLoop.instance().start()


router = SockJSRouter(Connection)
TornadoThread = TornadoThread()
TornadoThread.start()
c = Controller(storage_dir)