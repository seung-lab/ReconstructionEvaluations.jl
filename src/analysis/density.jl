function connection_probability(seg_list, edges)
    num_segs = size(seg_list,1)
    num_possible_connections = num_segs*(num_segs-1) / 2
    num_connections = size(edges,1)
    return num_connections / num_possible_connections
end