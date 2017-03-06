from tornado import web, ioloop, httpserver
from sockjs.tornado import SockJSConnection, SockJSRouter
import json 
from collections import OrderedDict
import numpy as np
import Tkinter as tk

clients = set()
n_messages = 0
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
        state = json.JSONDecoder(object_pairs_hook=OrderedDict).decode(json_state)
        global n_messages

        if not n_messages: #first message ever
            new_state = self.initialize_state(state)
        else:
            new_state = self.on_state_change(state)

        n_messages += 1
        if new_state: #if you return a new state send it back
            self.broadcast(clients, json.dumps(new_state))
        
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
        offset = np.array([17409,16385,16385])
        points = np.array([26249,22475,16822])
        state['layers']['synapses'] = {'type':'point', 'points':[(points-offset).tolist()]}
        state['layers']['segmentation']['segments'] = [6648872,640967]
        #state['navigation']['pose']['position']['voxelCoordinates'] = [(points-offset).tolist()]
        #state['navigation']['pose']['position']['zoomFactor'] = 1.0
        return state

    def on_state_change(self, state):
        """
        This is called every time there is a new state available
        (except the very first time).
        """
        # print(state['layers'])
        offset = np.array([17409,16385,16385])
        points = np.array([26249,22475,16822])
        state['navigation']['pose']['position']['voxelCoordinates'] = (points-offset).tolist()
        state['navigation']['pose']['position']['zoomFactor'] = 1.0
        print(state)
        return state         

# In order for the webbrowser to connect to this server
# add to the url 'stateURL':'http://localhost:9999'
router = SockJSRouter(Connection)
def broadcast(state):
    """
    Use this method to broadcast a new state to all connected clients.
    Without the need to wait for an `on_state_change`.
    """
    router.broadcast(clients, json.dumps(state))


socketApp = web.Application(router.urls)
http_server = httpserver.HTTPServer(socketApp, ssl_options={
    "certfile": "./certificate.crt",
    "keyfile": "./privateKey.key",
})
http_server.bind(9999) #port
http_server.start(1)
ioloop.IOLoop.instance().start()


def key(event):
    """shows key or tk code for the key"""
    if event.keysym == 'Escape':
        root.destroy()
    if event.char == event.keysym:
     # normal number and letter characters
        print( 'Normal Key %r' % event.char )
    elif len(event.char) == 1:
      # charcters like []/.,><#$ also Return and ctrl/key
        print( 'Punctuation Key %r (%r)' % (event.keysym, event.char) )
    else:
      # f1 to f12, shift keys, caps lock, Home, End, Delete ...
        print( 'Special Key %r' % event.keysym )

    if event.keysym == 'Up':
        print( 'Up' )

    if event.keysym == 'Down':
        print( 'Down' )
      

root = tk.Tk()
print( "Press a key (Escape key to exit):" )
root.bind_all('<Key>', key)
# don't show the tk window
# root.withdraw()
root.mainloop()