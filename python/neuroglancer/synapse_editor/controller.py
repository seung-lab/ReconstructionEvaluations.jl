import sys
from os.path import expanduser, join

import threading
from tornado import web, ioloop, httpserver
from sockjs.tornado import SockJSConnection, SockJSRouter
import json
from collections import OrderedDict

url = "https://neuromancer-seung-import.appspot.com/#!{'layers':{'image':{'type':'image'_'source':'precomputed://gs://neuroglancer/pinky40_v11/image'}_'segmentation':{'type':'segmentation'_'source':'precomputed://gs://neuroglancer/pinky40_v11/watershed_mst_trimmed_sem_remap'_'selectedAlpha':0.19_'segments':['122808597']_'equivalences':[['3877668'_'19326814'_'103591140']_['4277677'_'4277679'_'8379193'_'16842140'_'20545530'_'28070152'_'73839508']_['6425103'_'10754651'_'11795110'_'29542973'_'37433948'_'60747980'_'82481626'_'86081566'_'94050687']_['9166702'_'10182838'_'20502779'_'24194138'_'75235878'_'85382145'_'93217930']_['9255584'_'54548179']_['9502487'_'57892747'_'101059677']_['10737881'_'11373304'_'14297219'_'14355397'_'40365597'_'55341024'_'77919835'_'79127657']_['11495691'_'22992948'_'34268137'_'65111487'_'71915931'_'71988027'_'71988205'_'72062252'_'72063123'_'72135023'_'72135238'_'74729756'_'75513595'_'78667963'_'78809798'_'80202998'_'80205054'_'80205200'_'80210970'_'82855759'_'91832299'_'102803839']_['12665626'_'16234274'_'35447257'_'74766084'_'77947793'_'97748394'_'100084599']_['14291369'_'26736864'_'27315159'_'38130284'_'57565958'_'68310210'_'105481088'_'115472755']_['18944199'_'54824643'_'90471147']_['19044008'_'23289708'_'49884185'_'98835405'_'101666914'_'124353669']_['19609439'_'30600998'_'37568546'_'44985981'_'56721274'_'60133104'_'72320295'_'79667216']_['19841583'_'19842233'_'38937946'_'43131056'_'46393266'_'50627772'_'54110205'_'54111199'_'54113377'_'58128408'_'78618103'_'78618508'_'78618671'_'90519274'_'98618299'_'104847879'_'106399811'_'108650349'_'118641208']_['22582085'_'77416179'_'81383260'_'83286327'_'85039013'_'116999114']_['23645010'_'28527929'_'31476008'_'47930143'_'74119606'_'96961145']_['26098483'_'33376321'_'120222283']_['27071013'_'30927698'_'38468916'_'38539982'_'61686594']_['28362126'_'40139878'_'43965341'_'50440972'_'50558763'_'78665518']_['33636469'_'36665115'_'44514762'_'44515403'_'44515711'_'44993562'_'64468455'_'64468662'_'64615913'_'90703146'_'128080543']_['39283678'_'78879706'_'89583008'_'93740872'_'94851047']_['40102551'_'93652886']_['42766729'_'50227332']_['43098463'_'50725796'_'88852094']_['43836373'_'72380820']_['43865569'_'72205144'_'72828887'_'83631509'_'107876121']_['44140753'_'56607057'_'60687267'_'67920322'_'68205767'_'71749147'_'79139587'_'102854064'_'106664882'_'131506448']_['47936209'_'101023196']_['49727582'_'53136623'_'60420282'_'69938647'_'69944797'_'73870846'_'82007157'_'85531235'_'85739518'_'89344280'_'89414904'_'97141883'_'103741064'_'112034363'_'115377257'_'115413299'_'122910353'_'123316247'_'126527785']_['50996603'_'54996023'_'56179869'_'59016628'_'107860456']_['56627771'_'56682259'_'68830633'_'71743754'_'72646749'_'76434188'_'86482605'_'90749372'_'123211126']_['58045989'_'82937248'_'118730806']_['58237135'_'81728319'_'88764136'_'96468213']_['59520759'_'115244269'_'127126631'_'131011965']_['65727663'_'113907310']_['65959493'_'100323945'_'104528748'_'115696692'_'122808597']_['85733207'_'88948820'_'122609726']_['94563039'_'127566507']]}_'synapses':{'type':'point'_'points':[[24974_40428_510]_[22469_34463_726]_[17729_27568_533]_[11581_26404_568]_[22856_37130_632]]}_'psds':{'type':'segmentation'_'source':'precomputed://s3://neuroglancer/pinky40_v11/psdsegs_mst_trimmed_sem'_'visible':false}}_'navigation':{'pose':{'position':{'voxelSize':[4_4_40]_'voxelCoordinates':[25940.2578125_41584.19140625_452.14996337890625]}}_'zoomFactor':5.497982928501263}_'layout':'xy-3d'_'perspectiveZoom':3550.4394379836913_'perspectiveOrientation':[0.9823834300041199_0.032219208776950836_0.1755538284778595_0.055367611348629]_'showSlices':false_'stateURL':'https://localhost:7777'}"
print(url)

# need to run controller from ReconstructionEvaluations/src/neuroglancer
sys.path.append("../neuroglancer")
from model import Model

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
        self.synapses_on = True
        self.neighbors_on = True
        self.label = 'all'

    def update_segment_display(self):
        """Only update NG display with segments in model view.
           Useful when editting synapses, but toggling neighbors.
        """
        segs = model.get_segments(self.label, self.neighbors_on)
        current_state['layers']['segmentation']['segments'] = segs
        broadcast()

    def update_synapse_display(self):
        """Only update NG display with synapses in model view.
        """
        coords = model.get_coords(self.label) if self.synapses_on else []
        current_state['layers']['synapses'] = {'type':'point', \
                                                        'points':coords}
        broadcast()

    def update_display(self):
        """Update NG to display segments & synapses in model view.
        """
        print('Displaying ' + self.label)
        segs = model.get_segments(self.label, self.neighbors_on)
        current_state['layers']['segmentation']['segments'] = segs
        coords = model.get_coords(self.label) if self.synapses_on else []
        current_state['layers']['synapses'] = {'type':'point', \
                                                        'points':coords}
        broadcast()

    def get_segments(self):
        """Pull seg IDs displayed in NG
        """
        if 'segments' in current_state['layers']['segmentation']:
            return map(int, current_state['layers']['segmentation']['segments'])
        else:
            return []

    def get_center(self):
        """Get the center coordinate of current NG view.
        """
        c = current_state['navigation']['pose']['position']['voxelCoordinates']
        c = map(int, map(round, c))
        print(c)
        return c

    def set_segments(self, seg_ids):
        """Instantiate segments in the model, to display their synapses.
        """
        model.set_segments(seg_ids)
        self.update_display()

    def update_segments(self):
        """Pull seg IDs displayed in NG & instantiate them in the model.
        """
        seg_ids = self.get_segments()
        self.set_segments(seg_ids)

    def update_synapses(self):
        """Pull synapse coords displayed in NG & use them to update model edges.
        """
        coords = self.get_synapses()
        model.update_synapses(self.label, coords)

    def set_label(self, k):
        """Set label of the objects to be made visible
           e.g. 'pre', 'post', 'shared', 'all'
        """
        self.label = k
        self.update_display()

    def toggle_neighbors(self):
        """Toggle whether neighbors are displayed or not
        """
        self.neighbors_on = not self.neighbors_on
        return self.update_segment_display()

    def toggle_synapses(self):
        """Toggle whether synapses are displayed or not
        """
        self.synapses_on = not self.synapses_on
        return self.update_synapse_display()        

    def save(self):
        """Update the model edges, based on NG synapses, then save edges.
        """
        self.update_synapses()
        model.save()

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
        http_server.bind(7777) #port
        http_server.start(1)

    def run(self):
        print("IOLoop starting")
        ioloop.IOLoop.instance().start()


router = SockJSRouter(Connection)
TornadoThread = TornadoThread()
TornadoThread.start()
c = Controller()