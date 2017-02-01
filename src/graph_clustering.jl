function load_seg_sizes(fn)
    return readdlm(fn, ';', Int64)
end

"""
Return top n segment IDs based on sorted ID
"""
function filter_seg_ids_by_id(seg_sizes, n)
    return seg_sizes[sortperm(seg_sizes[:,1]),1][1:n]
end

"""
Return top n segment IDs based on segment size in voxels
"""
function filter_seg_ids_by_size(seg_sizes, n)
    return seg_sizes[seg_sizes[:,2] .>= n, 1]
end

"""
Select n-sized random set of segment IDs, if total vx above min_size
"""
function filter_seg_ids_randomly(seg_sizes, n, min_size=5000)
    ids = seg_sizes[seg_sizes[:,2] .>= min_size, 1]
    return ids[randperm(length(ids))[1:n]]

end

"""
Transform synapse voxel sizes (vary from 10^2-10^12)
"""
function reweight_adj!(adj)
    nzs = nonzeros(adj)
    for i in 1:length(nzs)
        nzs[i] = log(nzs[i])
    end 
end

"""
Make dicts w/ reverses for synapses & segments (rather than use edge array)
"""
function create_graph_dicts(edges, filter_ids=[], include_nulls=false)
    seg_to_index = Dict()
    index_to_seg = Dict()
    syn_to_segs = Dict()
    segs_to_syn = Dict()
    syn_coords = Dict()
    syn_size = Dict()
    for i in 1:size(edges,1)
        if edges[i,2][1] in filter_ids && edges[i,2][2] in filter_ids
            syn_to_segs[edges[i,1]] = edges[i,2]
            syn_coords[edges[i,1]]  = edges[i,3]
            syn_size[edges[i,1]]    = edges[i,4]
            segs_to_syn[edges[i,2]] = edges[i,1]
        end
    end
    segs = sort(filter_ids)
    if !include_nulls
        segs = sort(unique(vcat(values(syn_to_segs)...)))
    end
    for (k, seg) in enumerate(segs)
        seg_to_index[seg] = k
        index_to_seg[k]   = seg
    end

    return seg_to_index, index_to_seg, syn_to_segs, segs_to_syn, 
                                                        syn_coords, syn_size
end

"""
Create post to pre dicts with indices
"""
function create_post_pre_dicts(syn_to_segs)
    pre_to_post = Dict()
    post_to_pre = Dict()
    post_to_index = Dict()
    index_to_post = Dict()
    for (pre, post) in values(syn_to_segs)
        if !haskey(pre_to_post, pre)
            pre_to_post[pre] = []
        end
        if !haskey(post_to_pre, post)
            post_to_pre[post] = []
        end
        push!(pre_to_post[pre], post)
        push!(post_to_pre[post], pre)
    end
    for (k, post) in enumerate(keys(post_to_pre))
        post_to_index[post] = k
        index_to_post[k]   = post
    end
    return pre_to_post, post_to_pre, post_to_index, index_to_post
end

"""
Create (sparse) adjacency matrix with normalized synapse size as weight
"""
function create_adjacency_matrix(seg_to_index, syn_to_segs, syn_size)
    n = length(seg_to_index)
    adj = spzeros(n,n)
    for (syn, (pre, post)) in syn_to_segs
        u, v = seg_to_index[pre], seg_to_index[post]
        adj[u,v] += syn_size[syn]
    end
    return adj    
end

"""
Create adjacency matrix of dendrites innervated by the same axon
"""
function create_dendrite_adjacency_matrix(pre_to_post, post_to_pre, post_to_index)
    n = length(post_to_pre)
    adj = spzeros(n,n)
    for (post, pre_list) in post_to_pre
        u = post_to_index[post]
        for pre in pre_list
            for neighbor_post in pre_to_post[pre]
                if neighbor_post != post
                    v = post_to_index[neighbor_post]
                    adj[u,v] += 1
                end
            end
        end
    end
    return adj
end

"""
Return sort order for the adjacency matrix based on sign-based SVD clustering
"""
function svd_clustering(adj, k)
    o, _, _, _, _ = svds(adj, nsv=k)
    B = o.U
    x = zeros(size(adj,1),1)
    for i=1:k
        x += 2^(k-i)*B[:,i]
    end
    return sortperm(x[:])
end

"""
Return sort order for the adjacency matrix based on Louvain clustering

Uses community_louvain.m by Robinov, available at:
https://sites.google.com/site/bctnet/Home/functions
"""
function louvain_clustering(adj)
    if s1 == nothing
        init_MATLAB()
    end
    n = size(adj,1)
    M  = collect(1:n);          # initial community affiliations
    Q0 = -1; Q1 = 0;            # initialize modularity values
    put_variable(s1, :adj, adj)
    put_variable(s1, :M, M)
    while Q1-Q0>1e-5            # while modularity increases
        Q0 = Q1;                # perform community detection
        eval_string(s1, "[M, Q1] = community_louvain(adj, [], M);")
        Q1 = jscalar(get_mvariable(s1, :Q1))
        println("Q1: $Q1")
    end
    M = jvector(get_mvariable(s1, :M))
    return sortperm(M), Q1
end

"""
Display unclustered and clustered adjacency matrix side-by-side
"""
function view_order(adj, order=collect(1:size(adj,1)))
    # padding = ones(size(adj,1),100)
    subplot(121)
    imshow(adj, cmap=ColorMap("hot"))
    title("unclustered")
    xlabel("post")
    ylabel("pre")
    # colorbar()
    subplot(122)
    imshow(adj[order,order], cmap=ColorMap("hot"))
    title("clustered")
    xlabel("post")
    ylabel("pre")
    # colorbar()
end

"""
Load sparse matrix from file with format i, j, v
"""
function read_sparse(fn)
    d = readdlm(fn)
    n = Int64(maximum(d[:,1]))
    m = Int64(maximum(d[:,2]))
    S = spzeros(n,m)
    for i in 1:size(d,1)
        S[Int64(d[i,1]), Int64(d[i,2])] = d[i,3]
    end
    return S
end

"""
Write sparse matrix to file with format i, j, v
"""
function write_sparse(fn, arr)
    r = []
    c = []
    v = []
    rows = rowvals(arr)
    vals = nonzeros(arr)
    n = size(arr,1)
    for j in 1:n
        for i in nzrange(arr, j)
            push!(r, rows[i])
            push!(c, j)
            push!(v, vals[i])
        end
    end
    if length(nzrange(arr, n)) == 0
        push!(r, n)
        push!(c, n)
        push!(v, 0)
    end
    if !(n in rows)
        push!(r, n)
        push!(c, n)
        push!(v, 0)
    end

    writedlm(fn, hcat(r,c,v))
end

"""
Convert adjacency matrix indices back to segment IDs
"""
function get_segment_ids(index_to_seg, adj, perm, pre_range, post_range)
    pre_segs = []
    post_segs = []
    rows = rowvals(adj)
    n = size(adj,1)
    for j = 1:n
        for i in nzrange(adj, j)
            if rows[i] in pre_range && j in post_range
                # println((rows[i], j))
                push!(pre_segs, index_to_seg[perm[rows[i]]])
                push!(post_segs, index_to_seg[perm[j]])
            end
        end
    end
    return pre_segs, post_segs
end

"""
For given range of adj matrix, write out post & pre pairs & list of all seg IDs
"""
function write_cluster(dir, index_to_seg, adj, perm, pre_range, post_range)
    pre_segs, post_segs = get_segment_ids(index_to_seg, adj, perm, 
                                                pre_range, post_range)
    dt = Dates.format(Dates.today(), "yymmdd")
    cluster_name = string("$(dt)_cluster_20000_random_$(pre_range[1])-$(pre_range[end])_$(post_range[1])-$(post_range[end]).csv")
    cluster_fn = joinpath(dir, cluster_name)
    cluster_tbl = hcat(pre_segs, post_segs)
    writedlm(cluster_fn, cluster_tbl)
    cluster_name = string("$(dt)_cluster_20000_random_$(pre_range[1])-$(pre_range[end])_$(post_range[1])-$(post_range[end])_segs.csv")
    cluster_fn = joinpath(dir, cluster_name)
    cluster_tbl = unique(vcat(pre_segs, post_segs))
    open(cluster_fn, "w") do f
        write(f, join(cluster_tbl, " "))
        write(f, "\n")
    end
    # writedlm(cluster_fn, cluster_tbl)
end
