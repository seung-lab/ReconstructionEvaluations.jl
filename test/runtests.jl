#include("../src/ReconstructionEvaluations.jl")
using ReconstructionEvaluations
using Base.Test

include("test_count_table.jl")
include("test_overlap.jl")
include("test_geometry.jl")
include("test_syn_recovery.jl")
include("test_clustering.jl")
