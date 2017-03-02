
include("../ReconstructionEvaluations.jl");

# file write convention
dt = 170227
author = "tm"
fn = "u19_graph_clustering"
dir = joinpath(homedir(), "seungmount/research/tommy/s1/data");

# load edges and seg list
edges_fn = joinpath(dir, "170215_nt_combined_edges_cons.csv")
seg_list_fn = joinpath(dir, "170202_kl_seg_list.csv");
edges = load_edges(edges_fn);
# seg_list: id, size(vx), no synapses, pre/post category (post then pre)
seg_list = load_seg_list(seg_list_fn);
seg_list = quantify_pre_post(seg_list, edges);

# filter for pre-post counts
pre_post = count_segs_both_pre_and_post(edges[:,2])
post_only_count = 10
edge_prepost_filter = create_prepost_edge_mask(edges, pre_post, post_only_count);
filtered_edges = edges[edge_prepost_filter,:];

# filter for segment size
pre_min = 1e5
pre_max = 5e7
post_min = 7e5
post_max = 5e8
pre_filter = (seg_list[:,4] .== 1) & (pre_min .<= seg_list[:,2] .<= pre_max);
post_filter = (seg_list[:,4] .== 2) & (post_min .<= seg_list[:,2] .<= post_max);
seg_filter = pre_filter | post_filter
syn_to_segs, segs_to_syn, syn_coords, syn_size = create_graph_dicts(filtered_edges, seg_list[seg_filter,1])
segs = sort(unique(vcat(values(syn_to_segs)...)))
seg_to_index, index_to_seg = create_index_dict(segs);
pre_to_post, post_to_pre, pre_to_syn, post_to_syn = create_post_pre_syn_dicts(syn_to_segs);

# cluster
adj = create_adjacency_matrix(seg_to_index, syn_to_segs, syn_size);
reweight_adj!(adj) # apply log to the synapse weights
rand_order = randperm(size(adj,1))
radj = adj[rand_order,rand_order]
# Randomize adjacency matrix for better clustering results
radj_fn = joinpath(dir, "$(dt)_$(author)_rand_adj_sparse_$(fn).csv")
write_sparse(radj_fn, radj);

# Cluster the randomized matrix
cluster, louvain_order = louvain_clustering(radj);

# Read/write the permutations of the matrix sorting so the original segment IDs can be recovered
perm_fn = joinpath(dir, "$(dt)_$(author)_cluster_perm_$(fn).csv")
perm_tbl = hcat(collect(1:size(radj,1)), rand_order, louvain_order, round(Int64, cluster))
writedlm(perm_fn, perm_tbl)

# Sort the randomized matrix by its clustering order
cadj = radj[louvain_order, louvain_order]
cadj_fn = joinpath(dir, "$(dt)_$(author)_clustered_adj_sparse_$(fn).csv")
write_sparse(cadj_fn, cadj)
