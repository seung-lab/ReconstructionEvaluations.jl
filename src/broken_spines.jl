function find_peers(spine, post_to_pre, pre_to_post)
    pre_segs = post_to_pre[spine]
    # if length(pre_segs) == 1
    pre = pre_segs[1]
    post_segs = pre_to_post[pre]
    return spine, pre, post_segs
end

function get_synapses(pre, post_segs, segs_to_syn)
    return [segs_to_syn[(pre,post)] for post in post_segs]
end

function get_coords(synapses, syn_to_coords)
    return [syn_to_coords[syn] for syn in synapses]
end

function create_potential_trunk(spine, pre, post_segs, segs_to_syn, syn_to_coords)
end

function get_peers_distance(spine, pre, post_segs, segs_to_syn, syn_to_coords)
    synapses = get_synapses(pre, post_segs, segs_to_syn)
    coords = get_coords(synapses, syn_to_coords)
end

function get_peers_popularity(spine, pre, post_segs)
    popularity = countmap(post_segs)
    
end
