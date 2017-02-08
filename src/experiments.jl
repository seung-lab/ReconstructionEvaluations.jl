function pinky10_overlap()
    dir = joinpath(homedir(), "seungmount/Omni/TracerTasks/pinky/evaluation")
    base_fn = "chunk_19585-21632_22657-24704_4003-4258"
    gt_seg_fn = joinpath(dir, string(base_fn, "_proofread_compressed.h5"))
    orig_seg_fn = joinpath(dir, string(base_fn, "_original_compressed.h5"))

    valid_fn = joinpath(dir, string(base_fn, ".omni.segments.csv"))
    semantic_fn = joinpath(dir, string("semantic_", base_fn, ".csv"))
    semantic_list = load_semantic_list(semantic_fn)

    gt = subsample3d(load_segmentation(gt_seg_fn), (8,8,1))
    o = subsample3d(load_segmentation(orig_seg_fn), (8,8,1))

    gt_to_o = create_segID_map(gt, o, semantic_list)
    merges = count_splits(gt_to_o)
    semantic_list = append_splits(semantic_list, merges)

    overlap_list = unique(vcat(values(gt_to_o)...))

    o_to_gt = create_segID_map(o, gt, overlap_list)
    splits = count_splits(o_to_gt)
    semantic_list = append_splits(semantic_list, splits)

    seg_list = copy(semantic_list)
    den_splits = seg_list[seg_list[:,2] .== 3, 3] - 1
    plt[:hist](den_splits,bins=27)
    println("No of dendrite splits: $(sum(den_splits))")
end

function s1_graph_clustering()
    dt = Dates.format(Dates.today(), "yymmdd")
    fn = "20000_random"
    dir = joinpath(homedir(), "seungmount/research/tommy/s1/")
    edges_fn = joinpath(dir, "combined_edges.csv")
    edges = load_edges(edges_fn)
    seg_size_fn = joinpath(dir, "seg_size.csv")
    seg_size = load_seg_sizes(seg_size_fn)
    # filtered_seg_ids = filter_seg_ids_by_id(seg_size, 1000)
    # filtered_seg_ids = filter_seg_ids_by_size(seg_size, 5000)
    filtered_seg_ids = filter_seg_ids_randomly(seg_size, 20000, 5000)
    filtered_fn = joinpath(dir, "$(dt)_filtered_seg_ids_$(fn).csv")
    writedlm(filtered_fn, filtered_seg_ids)
    # d = create_graph_dicts(edges, seg_size[:,1])
    d = create_graph_dicts(edges, filtered_seg_ids)
    seg_to_index, index_to_seg, syn_to_segs, segs_to_syn, syn_coords, syn_size = d
    adj = create_adjacency_matrix(seg_to_index, syn_to_segs, syn_size)
    reweight_adj!(adj) # apply log to the synapse weights
    rand_order = randperm(size(adj,1))
    # view_order(adj, rand_order)
    radj = adj[rand_order,rand_order]
    # svd_order = svd_clustering(adj, 16)
    # view_order(radj, svd_order)

    radj_fn = joinpath(dir, "$(dt)_rand_adj_sparse_$(fn).csv")
    write_sparse(radj_fn, radj)

    # RUN ./GenLouvain/graph_clustering.m in MATLAB
    # (can't figure out how to load MEX files correctly in Julia)
    cluster, louvain_order = louvain_clustering(radj)
    # println("Louvain Q1: $Q1")
    view_order(radj, louvain_order)

    # louvain_fn = joinpath(dir, "$(dt)_louvain_order.csv")
    # radj = read_sparse(radj_fn)
    # louvain_fn = joinpath(dir, "$(dt)_louvain_order_large.csv")
    # louvain_order = readdlm(louvain_fn, Int64)[:]
    # view_order(radj, louvain_order)

    perm_fn = joinpath(dir, "$(dt)_cluster_perm_$(fn).csv")
    perm_tbl = hcat(collect(1:size(radj,1)), rand_order, louvain_order, round(Int64, cluster))
    writedlm(perm_fn, perm_tbl)

    cadj = radj[louvain_order, louvain_order]
    cadj_fn = joinpath(dir, "$(dt)_clustered_adj_sparse_$(fn).csv")
    write_sparse(cadj_fn, cadj)

    pre_to_post, post_to_pre, post_to_index, index_to_post = create_post_pre_dicts(syn_to_segs)
    dadj = create_dendrite_adjacency_matrix(pre_to_post, post_to_pre, post_to_index)
    dadj_fn = joinpath(dir, "$(dt)_dendrite_adj_sparse_$(fn).csv")
    write_sparse(dadj_fn, dadj)
    dadj_louvain_order, Q1 = louvain_clustering(dadj)
    println("Louvain Q1: $Q1")

    cdadj = dadj[dadj_louvain_order, dadj_louvain_order]
    cdadj_fn = joinpath(dir, "$(dt)_clustered_dendrite_adj_sparse_$(fn).csv")
    write_sparse(cdadj_fn, cdadj)

    perm = rand_order[louvain_order]
    write_cluster(dir, index_to_seg, cadj, perm, 12050:12390, 12050:12390)
end