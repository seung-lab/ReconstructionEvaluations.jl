"""
Return segment IDs of all segments in the valid list
"""
function load_valid_list(fn)
    vl = readdlm(fn, ',', Int64)
    return vl[vl[:,2] .== 2,1]
end

"""
Return Nx2 array with segment IDs and semantic labels
"""
function load_semantic_list(fn)
    return readdlm(fn, ',', Int64)
end

function load_segmentation(fn)
    return h5read(fn, "main");
end

function save_with_compression(fn, arr)
  f = h5open(fn, "w")
  f["main", "blosc", 3] = arr
  close(f)
end

"""
Subsample a 3D array
"""
function subsample3d(arr, n=(2,2,1))
    return arr[1:n[1]:end, 1:n[2]:end, 1:n[3]:end]
end

function create_segID_map(segA, segB)
    @assert size(segA) == size(segB)
    segA_ids = unique(segA)
    return create_segID_map(segA, segB, segA_ids)
end

"""
Create map of overlapping IDs from segA to segB
"""
function create_segID_map(segA, segB, segA_ids)
    @assert size(segA) == size(segB)
    id_map = Dict{Int64, Array{UInt32,1}}()
    for id in segA_ids
        id_mask = segA .== id
        id_map[id] = unique(segB[id_mask])
    end
    return id_map
end

"""
Count number of splits per seg ID
"""
function count_splits(segID_map)
    splits = Dict()
    for (segID, overlapIDs) in segID_map
        splits[segID] = length(overlapIDs)
    end
    return splits
end

"""
Splits should be interpreted like this:
    0: seg ID not in the original segmentation
    1: there was no merger in this segment
   >1: this segment was a merger, and was split x number of times
        (the sum of these splits, minus one per segment, should equal
         the number of seg IDs not in the original segmentation)

Merges should be interpreted like this:
    This segment required x number of merges to reach its final segmentation
"""
function append_splits(seg_list, split_dict)
    splits = []
    for i in 1:size(seg_list,1)
        if haskey(split_dict, seg_list[i])
            push!(splits, split_dict[seg_list[i]])
        else
            push!(splits, 0)
        end
    end
    return hcat(seg_list, splits)
end

"""
Filter list to be only segments with splits
"""
function get_splits(seg_list, label=2)
    s = copy(seg_list)
    s[:,3] = s[:,3]-1
    splits = s[s[:,2] .== label, :]
    return splits[splits[:,3] .!= 0, :]
end