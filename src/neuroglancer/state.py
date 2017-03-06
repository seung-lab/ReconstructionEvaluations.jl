import sys
from os.path import expanduser, join
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
home_dir = expanduser("~")
data_dir = join(home_dir, "seungmount/research/tommy/s1/data")
edges_fn = join(data_dir, "170303_tm_synapse_semantics_filtered_edges.csv")
edge_dicts = edges.create_edge_dicts(edges.load_edges(edges_fn))
syn_to_segs = edge_dicts[0]
segs_to_syn = edge_dicts[1]
syn_coords = edges.transform_coords(edge_dicts[2], 
                    offset=-np.array([17409,16385,16385]))
syn_size = edge_dicts[3]
seg_to_syn = edge_dicts[4]
pre_to_post = edge_dicts[5]
post_to_pre = edge_dicts[6]

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
            broadcast()

        
    def on_close(self):
        # If client disconnects, remove him from the clients list
        clients.remove(self)

    def initialize_state(self, state):
        """
        This is called once the connection is stablished
        """
        # for i in range(1,9):
            # cluster_fn = "/usr/people/tmacrina/seungmount/research/tommy/s1/data/cluster_synapses/170301_tm_cluster_" + str(i) + "_synapses.csv"
            # state['layers']['cluster' + str(i)] = {'type':'point', 'points':np.genfromtxt(cluster_fn).tolist()}
        # offset = np.array([17409,16385,16385])
        # points = np.array([26249,22475,16822])
        # state['layers']['synapses'] = {'type':'point', 'points':[(points-offset).tolist()]}
        # state['layers']['segmentation']['segments'] = [6648872,640967]
        #state['navigation']['posprint(info.path)e']['position']['voxelCoordinates'] = [(points-offset).tolist()]
        #state['navigation']['pose']['position']['zoomFactor'] = 1.0
        return state

    def on_state_change(self, state):
        """
        This is called every time there is a new state available
        (except the very first time).
        """
        # store position
        return state         

# In order for the webbrowser to connect to this server
# add to the url 'stateURL':'http://localhost:9999'
router = SockJSRouter(Connection)
def broadcast():
    """
    Use this method to broadcast a new state to all connected clients.
    Without the need to wait for an `on_state_change`.
    """
    # global receiving_message
    # if not receiving_message:
    router.broadcast(clients.copy(), json.dumps(current_state))

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
        print("setting up port")
        http_server.bind(9999) #port
        print("starting server")
        http_server.start(1)
    
    def run(self):
        print("IOLoop starting")
        ioloop.IOLoop.instance().start()

TornadoThread = TornadoThread()
TornadoThread.start()

def show_segment_event(event):
    try:
        seg_id = int(entry.get())
        show_synapses(seg_id)
        show_segment(seg_id)
        broadcast()
    except:
        print "try again"
        pass

def show_neighbors_event(event):
    # try:
    seg_id = int(entry.get())
    show_neighbors(seg_id)
    broadcast()
    # except:
    #     print "try again"
    #     pass

def show_synapses(seg_id, hold_on=False):
    print "show synapses"
    global current_state
    if seg_id in seg_to_syn:
        synapses = seg_to_syn[seg_id]
        coords = [syn_coords[s] for s in synapses]
        if hold_on:
            # if 'synapses' in current_state['layers']:
            points = current_state['layers']['synapses']['points'];
            print coords
            print points
            points.extend(coords)
            current_state['layers']['synapses'] = {'type':'point', \
                                                        'points':points}
            # else:
            #     current_state['layers']['synapses'] = {'type':'point', \
            #                                                 'points':coords}
        else:
            current_state['layers']['synapses'] = {'type':'point', \
                                                            'points':coords}
            set_voxelCoordinates(coords[0])
    else:
        print "segment ID not in edge list"
        pass

def show_segment(seg_id, hold_on=False):
    print "show segment"
    global current_state
    if hold_on:
        if 'synapses' in current_state['layers']:
            seg_ids = current_state['layers']['segmentation']['segments'];
            seg_ids.extend(seg_id)
            current_state['layers']['segmentation']['segments'] = seg_ids
        else:
            current_state['layers']['segmentation']['segments'] = [seg_id]
    else:
        current_state['layers']['segmentation']['segments'] = [seg_id]


def show_neighbors(seg_id):
    print "show neighbors"
    if seg_id in post_to_pre:
        for pre in post_to_pre[seg_id]:
            print pre
            show_synapses(pre, hold_on=True)
            show_segment(pre, hold_on=True)
    elif seg_id in pre_to_post:
        for post in pre_to_post[seg_id]:
            show_synapses(post, hold_on=True)
            show_segment(post, hold_on=True)
    else:
        print "segment ID not in edge list"
        pass

def set_voxelCoordinates(new_pos):
    """
    Set the voxelCoordinates to the numpy list
    """
    global current_state
    current_state['navigation']['pose']['position']['voxelCoordinates'] = new_pos

def update_voxelCoordinates(change_vector):
    """
    Adjust the voxelCoordinates by the numpy list change_vector
    """
    global current_state
    vc = current_state['navigation']['pose']['position']['voxelCoordinates']
    new_vc = (np.array(vc) + change_vector).tolist()
    current_state['navigation']['pose']['position']['voxelCoordinates'] = new_vc  

def shutdown(event):
    root.destroy()

print("setting up Tk")
root = tk.Tk()
tk.Label(root, text="segment ID").pack()
entry = tk.Entry(root)
entry.bind("<Return>", show_segment_event)
# entry.bind("<KP_Enter>", show_segment_event)
entry.bind("<KP_Enter>", show_neighbors_event)
entry.bind("<Escape>", shutdown)
entry.pack()
# e.grid(row=0,column=1)
# e.focus_set()
# tk.Button(root, text="Enter", command=show_cluster(e.get())).grid(row=2, sticky=tk.W, pady=4)
print( "Use input text to display segment & synapses.\n \
        Press 'c' to show neighbors.\n \
        Press Escape key to exit." )
# root.bind_all('<Key>', key)
# don't show the tk window
# root.withdraw()
root.mainloop()
