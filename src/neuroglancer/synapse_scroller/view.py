"""Lets just assume that we have the router already set up and we have the
global variables we need"""
import sys
sys.path.append("/usr/people/kluther/Documents/ReconstructionEvaluations/src/neuroglancer")
import state

class View(object):
    """Provides access to and functions to modify current_state"""
    @property
    def current_state(self):
        return state.current_state

    @current_state.setter
    def current_state(self, val):
        state.current_state = val

    def show_segment(self, seg_id, hold_on=False):
        """Updates current_state to show a different segment"""
        print "show segment"
        if hold_on:
            if 'synapses' in self.current_state['layers']:
                seg_ids = self.current_state['layers']['segmentation']['segments'];
                seg_ids.extend(seg_id)
                self.current_state['layers']['segmentation']['segments'] = seg_ids
            else:
                self.current_state['layers']['segmentation']['segments'] = [seg_id]
        else:
            self.current_state['layers']['segmentation']['segments'] = [seg_id]

    def clear_segments(self):
        """Updates current_state to unselect all segments"""
        self.current_state['layers']['segmentation']['segments'] = []

    def set_voxelCoordinates(self, new_pos):
        """Set the voxelCoordinates to the numpy list"""
        self.current_state['navigation']['pose']['position']['voxelCoordinates'] = new_pos

    def show_synapses(self, coords, hold_on=False):
        """Updates state to label all synapse coords"""
        if hold_on:
            points = self.current_state['layers']['synapses']['points']
            points.extend(coords)
            self.current_state['layers']['synapses'] = {'type':'point', \
                                                        'points':points}

        else:
            self.current_state['layers']['synapses'] = {'type':'point', \
                                                            'points':coords}
            self.set_voxelCoordinates(coords[0])


#Testing
if __name__=="__main__":
    v = View()
    import pdb; pdb.set_trace()
    import time; time.sleep(2)
    v.show_segment(2)
