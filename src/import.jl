"""
Load segment size list
"""
function load_seg_list(fn)
    return readdlm(fn, ';', Int64)
end

"""
Load Synaptor edge csv & parse columns appropriately
"""
function load_edges(fn)
    tbl = readdlm(fn, ';')[:,1:4]
    tbl[:,2] = [map(parse, split(tbl[i,2][2:end-1],",")) for i in 1:size(tbl,1)]
    tbl[:,3] = [map(parse, split(tbl[i,3][2:end-1],",")) for i in 1:size(tbl,1)]
    return tbl
end

"""
Load Omni working/valid/uncertain
"""
function load_valid_list(fn)
	return readdlm(fn, ',', Int64)
end
