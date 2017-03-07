module ReconstructionEvaluations

using MATLAB
using HDF5
using StatsBase
using PyPlot
using Graphics
using FastConv

#plt[:style][:use]("ggplot")

export 
    load_edges,
    edges_to_syn_dicts,
    segm_overlap, overlap_in_chunks, create_segID_map,
    map_synapses,
    get_indexed_seg_IDs,
    build_count_table,
    compute_nri,
    merge_columns,
    split_column,
    remove_synapse,
    add_synapse,
    merge_sensitivity,
    split_sensitivity,
    NRI,
    #synapse recovery estimates
    find_trunk_mapping, synapse_recovery,
    Vec3, Point3, BoundingCube,
    # limits in world coordinates
    isinside, xmin, xmax, ymin, ymax, zmin, zmax, center, 
    xrange, yrange, zrange, shift, deform,
    width, height, depth,
    # clustering methods
    read_sparse, write_sparse,
    load_seg_sizes, classify_pre_post,
    hist_seg_sizes


include("utils/include.jl")
include("eval/include.jl")
include("analysis/include.jl")
include("CronUtils/include.jl")
include("experiments/experiments.jl")

end
