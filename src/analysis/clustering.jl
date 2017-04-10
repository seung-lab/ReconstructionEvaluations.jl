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

function create_weighted_seg_list(seg_list)
    weighted_seg_list = copy(seg_list)
    for i in 1:size(seg_list,1)
        for k in 2:round(Int64,seg_list[i,3])
            weighted_seg_list = vcat(weighted_seg_list, seg_list[[i],:])
        end
    end
    return weighted_seg_list
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
Augment seg_list with frequency of seg id & class as dendrite or axon (2 or 3)
"""
function quantify_pre_post(seg_list, edges)
    segs = hcat(edges[:,2]...)'
    pre = segs[:,1]
    post = segs[:,2]
    upre = unique(pre)
    upost = unique(post)
    seg_list = hcat(seg_list, zeros(Int64, size(seg_list,1), 2))
    for i in 1:size(seg_list,1)
        if seg_list[i,1] in upost
            seg_list[i,end-1] = length(post[post .== seg_list[i,1]])
            seg_list[i,end] = 2
        elseif seg_list[i,1] in upre
            seg_list[i,end-1] = length(pre[pre .== seg_list[i,1]])
            seg_list[i,end] = 1
        else
            seg_list[i,end] = 3
        end
    end
    return seg_list
end

"""
Make dicts w/ reverses for synapses & segments (rather than use edge array)

Inputs:
    edges:  Nx4 array - syn ID, [pre ID, post ID], [syn coord], syn size
    filter_ids: list of segment IDs that should be included
"""
function create_graph_dicts(edges, filter_ids)

    function push_dict!(d, k, v)
        if !haskey(d, k)
            d[k] = Array{Int64,1}()
        end
        push!(d[k], v)
    end

    syn_to_segs = Dict()
    segs_to_syn = Dict()
    seg_to_syn = Dict()
    syn_coords = Dict()
    syn_size = Dict()
    pre_to_post = Dict()
    post_to_pre = Dict()
    for i in 1:size(edges,1)
        if edges[i,2][1] in filter_ids && edges[i,2][2] in filter_ids
            syn_to_segs[edges[i,1]] = edges[i,2]
            syn_coords[edges[i,1]]  = edges[i,3]
            syn_size[edges[i,1]]    = edges[i,4]
            push_dict!(segs_to_syn, edges[i,2], edges[i,1])
            for e in edges[i,2]
                push_dict!(seg_to_syn, e, edges[i,1])
            end
            push_dict!(pre_to_post, edges[i,2][1], edges[i,2][2])
            push_dict!(post_to_pre, edges[i,2][2], edges[i,2][1])
        end
    end

    return syn_to_segs, segs_to_syn, syn_coords, syn_size, seg_to_syn, pre_to_post, post_to_pre
end

"""
Create post to pre dicts from Nx2 list of pre post pairs
"""
function create_post_pre_dicts(segs::Array)
    # segs = hcat(edges[:,2]...)'
    pre_to_post = Dict()
    post_to_pre = Dict()
    for k in 1:size(segs,1)
        pre, post = segs[k,:]
        if !haskey(pre_to_post, pre)
            pre_to_post[pre] = Array{Int64,1}()
        end
        if !haskey(post_to_pre, post)
            post_to_pre[post] = Array{Int64,1}()
        end
        push!(pre_to_post[pre], post)
        push!(post_to_pre[post], pre)
    end
    return pre_to_post, post_to_pre
end

"""
Create post to pre dicts with indices
"""
function create_post_pre_syn_dicts(syn_to_segs::Dict)
    post_to_syn = Dict()
    pre_to_syn = Dict()
    pre_to_post = Dict()
    post_to_pre = Dict()
    post_to_index = Dict()
    index_to_post = Dict()
    for (syn, (pre, post)) in syn_to_segs
        if !haskey(pre_to_post, pre)
            pre_to_post[pre] = []
        end
        if !haskey(post_to_pre, post)
            post_to_pre[post] = []
        end
        push!(pre_to_post[pre], post)
        push!(post_to_pre[post], pre)

        if !haskey(post_to_syn, post)
            post_to_syn[post] = []
        end
        if !haskey(pre_to_syn, pre)
            pre_to_syn[pre] = []
        end
        push!(pre_to_syn[pre], syn)
        push!(post_to_syn[post], syn)
    end
    return pre_to_post, post_to_pre, pre_to_syn, post_to_syn
end

"""
Count segments that are both pre & post

Input:
    pre_to_syn: dict of pre seg id to list of synapses
    post_to_syn: dict of post seg id to list of synapses

Output:
    Dict of seg_id, no of pre synapses, no of post synapses
"""
function count_segs_both_pre_and_post(pre_to_syn::Dict, post_to_syn::Dict)
    pre_post = Dict()
    post = keys(post_to_syn)
    for k in keys(pre_to_syn)
        if k in post
            pre_post[k] = [length(pre_to_syn[k]), length(post_to_syn[k])]
        end
    end
    return pre_post
end

"""
Count segments that are both pre & post

Input:
    edges: N-element list of 2-element arrays with pre, post seg pairs as edges

Output:
    Dict of seg_id, no of pre synapses, no of post synapses
"""
function count_segs_both_pre_and_post(edges::Array)
    segs = hcat(edges...)
    pre = segs[1,:]
    post = segs[2,:]
    pre_post = Dict()
    for i in 1:size(segs,2)
        pre = segs[1,i]
        post = segs[2,i]
        if haskey(pre_post, pre)
            pre_post[pre][1] += 1
        else
            if pre in segs[2,i:end]
                pre_post[pre] = [1, 0]
            end
        end
        if haskey(pre_post, post)
            pre_post[post][2] += 1
        else
            if post in segs[1,i:end]
                pre_post[post] = [0, 1]
            end
        end
    end
    return pre_post
end

"""
Create (sparse) adjacency matrix with normalized synapse size as weight
"""
function create_weighted_adjacency_matrix(seg_to_index, syn_to_segs, syn_size)
    n = length(seg_to_index)
    adj = spzeros(n,n)
    for (syn, (pre, post)) in syn_to_segs
        u, v = seg_to_index[pre], seg_to_index[post]
        adj[u,v] += syn_size[syn]
    end
    return adj
end

"""

    create_connectivity_adjacency_matrix(seg_to_index, syn_to_segs, binary=true)
    
Create (sparse) adjacency matrix with normalized synapse size as weight
"""
function create_connectivity_adjacency_matrix(seg_to_index, syn_to_segs, binary=true)
    n = length(seg_to_index)
    adj = spzeros(n,n)
    for (syn, (pre, post)) in syn_to_segs
        u, v = seg_to_index[pre], seg_to_index[post]
        if binary  adj[u,v] = 1
        else       adj[u,v] += 1
        end
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
    check_MATLAB()
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
    return M, sortperm(M)
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
Count the elements in each cluster
"""
function count_clusters(cluster)
    cluster_ids = sort(unique(cluster))
    return cluster_ids, [sum(cluster .== id) for id in cluster_ids]
end

"""
Create dict of cluster index ranges based on cluster ID
"""
function get_sorted_cluster_ranges(cluster)
    cluster_ids, cluster_counts = count_clusters(cluster)
    cluster_ranges = Dict()
    k = 1
    for (id, c) in zip(cluster_ids, cluster_counts)
        l = k+c-1
        cluster_ranges[id] = (k:l)
        k = l+1
    end
    return cluster_ranges
end

"""
Create dict of segment IDs based on cluster ID
"""
function get_cluster_segs(perm, cluster_ranges, index_to_seg)
    cluster_to_segs = Dict()
    for (id, cluster_range) in cluster_ranges
        indices = perm[cluster_range]
        cluster_to_segs[id] = []
        for ind in indices
            push!(cluster_to_segs[id], index_to_seg[ind])
        end
    end
    return cluster_to_segs
end

"""
Create dict for cluster ID to table of pre ID & post IDs
"""
function get_cluster_to_pre_post(perm, adj, index_to_seg, cluster_ranges)
    cluster_to_pre_post = Dict()
    for (cluster_id, cluster_range) in cluster_ranges
        pre_segs, post_segs = get_segment_ids(perm, adj, index_to_seg,
                                                cluster_range, cluster_range)
        cluster_tbl = hcat(pre_segs, post_segs)
        cluster_to_pre_post[cluster_id] = cluster_tbl
    end
    return cluster_to_pre_post
end

"""
Create dict for cluster ID pairs with table of pre ID & post IDs

This is to get connections within and between clusters
"""
function get_pair_cluster_to_pre_post(perm, adj, index_to_seg, cluster_ranges)
    cluster_to_pre_post = Dict()
    for (id_A, range_A) in cluster_ranges
        for (id_B, range_B) in cluster_ranges
            pre_segs, post_segs = get_segment_ids(perm, adj, index_to_seg,
                                                            range_A, range_B)
            cluster_tbl = hcat(pre_segs, post_segs)
            cluster_to_pre_post[(id_A,id_B)] = cluster_tbl
        end
    end
    return cluster_to_pre_post
end

"""
Convert adjacency matrix indices back to segment IDs
"""
function get_segment_ids(perm, adj, index_to_seg, pre_range, post_range)
    pre_segs = []
    post_segs = []
    rows = rowvals(adj)
    n = size(adj,1)
    for j = 1:n
        for i in nzrange(adj, j)
            if rows[i] in pre_range && j in post_range
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
