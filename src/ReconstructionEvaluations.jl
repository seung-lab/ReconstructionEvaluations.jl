module ReconstructionEvaluations

using MATLAB
using HDF5
using PyPlot

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
    split_sensitivity

# MATLAB session variable
global s1 = nothing

include("count_table.jl")
include("overlap.jl")

end