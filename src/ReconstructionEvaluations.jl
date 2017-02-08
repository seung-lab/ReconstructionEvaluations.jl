# module ReconstructionEvaluations

using MATLAB
using HDF5
using StatsBase
using PyPlot
using Graphics

export 
    load_edges,
    edges_to_syn_dicts,
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
    Vec3, Point3, BoundingCube,
    # limits in world coordinates
    isinside, xmin, xmax, ymin, ymax, zmin, zmax, center, 
    xrange, yrange, zrange, shift, deform,
    width, height, depth,
    # clustering methods
    read_sparse, write_sparse,
    load_seg_sizes, classify_pre_post,
    hist_seg_sizes

include("matlab.jl")
include("count_table.jl")
include("overlap.jl")
include("graph_clustering.jl")
include("geometry.jl")
include("visualize.jl")

# end