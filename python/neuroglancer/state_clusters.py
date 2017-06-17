import sys
import threading
from tornado import web, ioloop, httpserver
from sockjs.tornado import SockJSConnection, SockJSRouter
import json 
from collections import OrderedDict
import numpy as np
import Tkinter as tk
import edges

clients = set()
n_messages = 0
current_state = None
receiving_message = False

# offset = np.array([17409,16385,16385])
assert len(sys.argv) > 1
cluster_fn = sys.argv[1]
cluster_to_segs, seg_to_cluster = edges.load_clusters(cluster_fn)


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
        self.root = tk.Tk()
        self.root.bind("<Escape>", self.shutdown)
        self.root.title("NG State")

        self.cluster_id = tk.StringVar()
        self.cluster_id.set("")
        self.cluster_id_entry = self.create_textbox(self.show_cluster_event, 
                                                self.cluster_id, "cluster_id")

    def start(self):
        self.root.mainloop()

    def shutdown(self, event):
        self.root.destroy()

    def show_cluster_event(self, event):
        cluster_id = int(self.cluster_id_entry.get())
        self.show_cluster(cluster_id)

    def show_cluster(self, k):
        print('show cluster ' + str(k))
        try:
            all_segs = np.array(cluster_to_segs[k])
            n = len(all_segs)
            fr = 0.01
            # m = int(round(fr*n))
            m = 20
            print(str(m) + "/" + str(n))
            segs = all_segs[np.random.permutation(n)[:m]].tolist()
            current_state['layers']['segmentation']['segments'] = segs
            broadcast()
        except RuntimeError as err:
            print(err)
            pass

    def create_textbox(self, action, textvar, caption=""):
        """Creates textbox that will execute action when enter is pressed.
        """
        label = tk.Label(self.root, text=caption).pack(side=tk.LEFT)
        entry = tk.Entry(self.root, textvariable=textvar)
        entry.bind("<Return>", action)
        entry.pack(side=tk.LEFT)
        return entry

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
c.start()
