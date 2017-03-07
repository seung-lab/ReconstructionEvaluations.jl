"""
Convert edge table into set of synapse-key dictionaries.

Output:
    dict with presynaptic segments
    dict with postsynaptic segments
    dict with synaptic centroid coordinates
"""
function edges_to_syn_dicts(tbl)
    pre = Dict()
    post = Dict()
    for i in 1:size(tbl,1)
        synID = tbl[i,1]
        pre[synID] = tbl[i,2][1]
        post[synID] = tbl[i,2][2]
    end
    return pre, post
end

"""
Find matching synapse in list of synapse locations given location of one synapse

Input:
    coordinate of particular synapse
    list of synase coordinates
Output:
    index of most similar synapse coordinate

For now, assume that synapse coordinates exactly line up
"""
function find_matching_synapse(syn_A, list_of_syn_B)
    return findfirst(list_of_syn_B, syn_A)
end

"""
For two sets of synapses labels on a given volume, map one set to the other

Input:
	synapse set A IDs with centroid location as 3-element coordinate (Ax2 array)
	synapse set B IDs with centroid location as 3-element coordinate (Bx2 array)

Output:
	Nx2 array: 
		col 1: synapse set A IDs
		col 2: associated synapse set B IDs
		If there is no associated ID, that column entry will be 0
"""
function map_synapses(tbl_A, tbl_B)
    synA_to_synB = []
    for i in 1:size(tbl_A,1)
        ind_B = find_matching_synapse(tbl_A[i,3], tbl_B[:,3])
        if ind_B != 0
            push!(synA_to_synB, [tbl_A[i,1], tbl_B[ind_B,1]])
        else
            push!(synA_to_synB, [tbl_A[i,1], 0])
        end
    end

    for i in 1:size(tbl_B,1)
        ind_A = find_matching_synapse(tbl_B[i,3], tbl_A[:,3])
        if ind_A == 0
            push!(synA_to_synB, [0, tbl_B[i,1]])
        end
    end
    return hcat(synA_to_synB...)'
end

"""
Construct table for NRI from two edge tables (see Synaptor by N Turner)

Input:
    edge tables for two reconstructions

Output:
    (A+1)x(B+1) sparse count table built according to:
                '160618 - Computing NRI, Documentation.pdf'
        1st column & 1st row are FP
    lookup of row index to segment ID (considers row 2 to be index 1)
    lookup of col index to segment ID (considers col 2 to be index 1)

"""
function build_count_table(tbl_A, tbl_B)
    synA_to_synB = map_synapses(tbl_A, tbl_B)
    A_to_inds, inds_to_A = get_indexed_seg_IDs(tbl_A, 1)
    preA, postA = edges_to_syn_dicts(tbl_A)
    B_to_inds, inds_to_B = get_indexed_seg_IDs(tbl_B, 1)
    preB, postB = edges_to_syn_dicts(tbl_B)
    count_table = zeros(Int64, length(A_to_inds)+1, length(B_to_inds)+1)
    for k in 1:size(synA_to_synB,1)
        synA, synB = synA_to_synB[k,:]
        for (segA,segB) in [(preA,preB), (postA,postB)]
            if synA > 0
                i = A_to_inds[segA[synA]]
            else
                i = 1
            end
            if synB > 0
                j = B_to_inds[segB[synB]]
            else
                j = 1
            end
            count_table[i,j] += 1
        end
    end
    return count_table, A_to_inds, B_to_inds
end

"""
Simulate a merge error in the count table
"""
function merge_columns(count_table, i, j)
    @assert 1 < i <= size(count_table,1)
    @assert 1 < j <= size(count_table,2)
    # @assert i != j
    count_table[:,i] = count_table[:,i] + count_table[:,j]
    return count_table[:,[collect(1:j-1)...,collect(j+1:end)...]]
end

"""
Simulate a split error in the count table
"""
function split_column(count_table, j)
    @assert 1 < j <= size(count_table,2)
    # no need to unnecessarily split a segment that only has one synapse
    if sum(count_table[:,j]) > 1
        orig = count_table[:,j]
        split = count_table[:,j]
        syn_split = [rand(1:syn_count-1) for syn_count in orig[orig .> 1]]
        split[orig .> 1] = syn_split
        orig[orig .> 1] -= syn_split
        return hcat(count_table[:,1:j-1], orig, split, count_table[:,j+1:end])
    end
    return count_table
end

"""
Simulate a missed synapse in the count table
"""
function remove_synapse(count_table, pre_pair, post_pair)
    for (i,j) in [pre_pair, post_pair]
        @assert 1 < i <= size(count_table,1)
        @assert 1 < j <= size(count_table,2)
    end
    for (i,j) in [pre_pair, post_pair]
        if count_table[i,j] > 0
            count_table[i,j] -= 1
            count_table[i,1] += 1
        end
    end
    return count_table
end

"""
Simulate an added synapse in the count table
"""
function add_synapse(count_table, seg_pair)
    for j in seg_pair
        @assert 1 < j <= size(count_table,2)
    end
    for j in seg_pair
        count_table[1,j] += 1
    end
    return count_table
end
