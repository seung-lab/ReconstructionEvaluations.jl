"""
Start MATLAB session for NRI calculation
"""
function init_MATLAB()
    println("Starting MATLAB session...")
    global s1 = MSession()
    cwd = joinpath(Pkg.dir("ReconstructionEvaluations"), "src")
    println("Changing MATLAB userpath to $cwd")
    eval_string(s1, "userpath('$cwd')")
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
        ind_B = findfirst(tbl_B[:,3], tbl_A[i,3])
        if ind_B != 0
            push!(synA_to_synB, [tbl_A[i,1], tbl_B[ind_B,1]])
        else
            push!(synA_to_synB, [tbl_A[i,1], 0])
        end
    end

    for i in 1:size(tbl_B,1)
        ind_A = findfirst(tbl_A[:,3], tbl_B[i,3])
        if ind_A == 0
            push!(synA_to_synB, [0, tbl_B[i,1]])
        end
    end
    return hcat(synA_to_synB...)'
end

"""
Create dict of all segment IDs contained within edge table & ranked index

Output:
    Dict (k,v):(segment IDs, rank of segment ID in all segment IDs)
"""
function get_indexed_seg_IDs(tbl)
    ids = sort(unique(vcat(tbl[:,2]...)))
    seg_indices = Dict()
    for (i, id) in enumerate(ids)
        seg_indices[id] = i
    end
    return seg_indices
end

"""
Construct table for NRI from two edge tables (see Synaptor by N Turner)

Input:
    edge tables for two reconstructions

Output:
    (A+1)x(B+1) count table built according to:
                '160618 - Computing NRI, Documentation.pdf'
        1st column & 1st row are FP
"""
function build_count_table(tbl_A, tbl_B)
    synA_to_synB = map_synapses(tbl_A, tbl_B)
    indsA = get_indexed_seg_IDs(tbl_A)
    preA, postA = edges_to_syn_dicts(tbl_A)
    indsB = get_indexed_seg_IDs(tbl_B)
    preB, postB = edges_to_syn_dicts(tbl_B)
    count_table = zeros(Int64, length(indsA)+1, length(indsB)+1)
    for k in 1:size(synA_to_synB,1)
        synA, synB = synA_to_synB[k,:]
        for (segA,segB) in [(preA,preB), (postA,postB)]
            if synA > 0
                i = indsA[segA[synA]] + 1
            else
                i = 1
            end
            if synB > 0
                j = indsB[segB[synB]] + 1
            else
                j = 1
            end
            count_table[i,j] += 1
        end
    end
    return count_table    
end

"""
Run the T&E team MATLAB function on the count table
"""
function compute_nri(count_table)
    if s1 == nothing
        init_MATLAB()
    end
    put_variable(s1, :x, count_table)
    # return mxcall(:nri, 1, count_table)
    eval_string(s1, "n = nri(double(x));")
    return jscalar(get_mvariable(s1, :n))
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

function merge_sensitivity(count_table, n)
    f1 = []
    c = count_table
    for k=1:n
        sz = size(c)
        i = rand(2:sz[2])
        j = rand(2:sz[2])
        # println((sz, (i,j)))
        c = merge_columns(c, i, j);
        push!(f1, compute_nri(c))
   end
   return f1, c
end

function split_sensitivity(count_table, n)
    f1 = []
    c = count_table
    for k=1:n
        # always pick a neuron with more than 2 synapses to split
        gt_one = collect(2:size(c,2))[sum(c[:,2:end],1) .> 1]
        j = rand(gt_one)
        c = split_column(c, j);
        push!(f1, compute_nri(c))
        # println(f1[end])
   end
   return f1, c
end