"""
Convert list of 3d coordinates to a BoundingCube
"""
function coords_to_bc(coords)
	pts = map(Vec3, coords)
	return BoundingCube(pts...)
end

"""
Filter an edge list to contain edges only within a BoundingCube
"""
function filter_edges(filter_bc, edges)
    pts = [Vec3(edges[i,3]...) for i in 1:size(edges,1)]
    inside = [is_inside(filter_bc, pt) for pt in pts]
    return edges[inside, :]
end

"""
Create index lookup dictionaries for a list of values

Note: used to help create adjacency matrix
"""
function create_index_dict(list)
    v_to_index = Dict()
    index_to_v = Dict()
    for (ind, v) in enumerate(list)
        v_to_index[v] = ind
        index_to_v[ind] = v
    end
    return v_to_index, index_to_v
end

"""
Create dict of all segment IDs contained within edge table & ranked index

Output:
    Dict (k,v):(segment IDs, rank of segment ID in all segment IDs)
"""
function get_indexed_seg_IDs(tbl)
    ids = sort(unique(vcat(tbl[:,2]...)))
    return create_index_dict(ids)
end

"""
Return list of dict keys as sorted by values

Input:
    d: dictionary with sortable values (no check for partial order)

Output:
    list of keys
"""
function sort_keys_by_val(d)
    return collect(keys(d))[sortperm(collect(values(d)))]
end

"""
Filter edges by a random bounding cube of size filter_dims (nm) @ resolution

Input:
    filename of edge list #1
    filename of edge list #2
    filter_dims: 3-element array with filtering dimensions in nm
    resolution: 3-element array with voxel dimensions in nm

Output:
    edge list #1 filtered by random bounding cube with size filter_dims
    edge list #2 filtered by random bounding cube with size filter_dims
"""
function load_and_filter_edges(proofread_fn::AbstractString, raw_fn::AbstractString, filter_dims=[4000,4000,4000], resolution=[6,6,30])
    return load_and_filter_edges(load_edges(proofread_fn), 
                        load_edges(raw_edges), filter_dims, resolution)
end

"""
Filter edges by a random bounding cube of size filter_dims (nm) @ resolution

Input:
    edge list #1
    edge list #2
    filter_dims: 3-element array with filtering dimensions in nm
    resolution: 3-element array with voxel dimensions in nm

Output:
    edge list #1 filtered by random bounding cube with size filter_dims
    edge list #2 filtered by random bounding cube with size filter_dims
"""
function load_and_filter_edges(proofread_edges::Array, raw_edges::Array, filter_dims=[4000,4000,4000], resolution=[6,6,30])
    coords = vcat(proofread_edges[:,3], raw_edges[:,3])
    all_bc = BoundingCube([Vec3(c...) for c in coords]...)
    filter_px = filter_dims ./ resolution
    rand_xmin = rand(xmin(all_bc):xmax(all_bc)-filter_px[1])
    rand_ymin = rand(ymin(all_bc):ymax(all_bc)-filter_px[2])
    rand_zmin = rand(zmin(all_bc):zmax(all_bc)-filter_px[3])
    rand_bc = BoundingCube(rand_xmin, rand_xmin+filter_px[1], rand_ymin, rand_ymin+filter_px[2], 
                                                                            rand_zmin, rand_zmin+filter_px[3])
    return filter_edges(rand_bc, raw_edges), filter_edges(rand_bc, proofread_edges)
end