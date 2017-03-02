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

"""
Make a dense 3D mask of locations, scaled accordingly

Input:
    list of coordinates (like edges[:,3])
    scale: 3-element array with scaling in each dimension

Output:
    3D dense Float32 matrix
    origin of the dense matrix
"""
function make_3D_mask(coords, scale=[1,1,1])
    pts = [Vec3(c.*scale...) for c in coords]
    bc = BoundingCube(pts...)
    vol = zeros(Float32, collect(map(Int64, map(round, size(bc)))) + 2 ...)
    origin = round(min(bc))
    for pt in pts
        vol[map(Int64, collect(round(pt) - origin) + 1)...] = 1
    end
    return vol, origin
end

function make_3D_mask(coords, scale=[1,1,1], sz=[160,145,145])
    pts = [Vec3(c.*scale...) for c in coords]
    bc = BoundingCube(pts...)
    vol = zeros(Float32, sz...)
    origin = Vec3(281.0,274.0,1280.0)
    for pt in pts
        vol[map(Int64, collect(round(pt) - origin) + 1)...] = 1
    end
    return vol, origin
end

"""
Create symmetric 3d gaussian, of only odd size dimension n
"""
function create_3d_gaussian(n, sigma, T=Float32)
    if n%2 == 0
        n += 1
    end
    g = zeros(T, n,n,n)
    m = T(n)
    s = [m/2, m/2, m/2]
    A = eye(T, 3)*sigma
    den = sqrt(det(2*pi*A))
    for i in 1:n
        for j in 1:n
            for k in 1:n
                x = [i,j,k]
                g[x...] = 1/den*exp(-0.5*(x-s)'*A^-1*(x-s))[1]
            end
        end
    end
    return g
end

"""
Create mask of rows in edges based on:
 (1) the presynaptic edge is not merged
 (2) the merged postsynaptic edge is not merged or has more than n synapses

Input:
    edges: Nx4 array from load_edges
    pre_post: dict of pre_post seg ids to pre synapse & post synapse counts
    post_only_count: scalar for synapse threshold that merged post targets
     must meet

Output:
    N-element bit mask for rows of the edges that meet the above criteria
"""
function create_prepost_edge_mask(edges, pre_post, post_only_count)
    edge_prepost_filter = falses(size(edges,1));
    post_only_count = 10
    for i in 1:size(edges,1)
        pre = edges[i,2][1]
        post = edges[i,2][2]
        if !(haskey(pre_post, pre)) & haskey(pre_post, post)
            if (pre_post[post][2] >= post_only_count)
                edge_prepost_filter[i] = true
            end
        elseif !(haskey(pre_post, pre)) & !(haskey(pre_post, post))
            edge_prepost_filter[i] = true
        end
    end
    return edge_prepost_filter
end