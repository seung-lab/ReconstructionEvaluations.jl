#!/usr/bin/env julia

import ReconstructionEvaluations
import ReconstructionEvaluations.Cron.Synaptor
const RE = ReconstructionEvaluations

import Drivers
using HDF5

seg_fname = ARGS[1]
output_prefix = ARGS[2]


#-------------------------
comparison_seg = "data/pinky_golden_cube_021717.h5"
comparison_edges = "data/pinky_golden_cube_021717_edges.csv"

dist_thr = 1000
res = [4,4,40]

overlap_chunk_shape = [1024,1024,128]
#-------------------------

score_h5 = "$(output_prefix)_scores.h5"

#==
Running Synaptor postprocessing
==#
println("RUNNING SYNAPTOR POSTPROCESSING")

cfg = Synaptor.make_gc_cfg(seg_fname, output_prefix)

edge_fname = Drivers.run_synaptor_cfg( cfg )

#==
Computing NRI score
==#
println("")
println("COMPUTING NRI")

@time full_nri, seg_nris = RE.compute_nri( edge_fname, comparison_edges )


h5write( score_h5, "NRI", full_nri )
h5write( score_h5, "seg_NRIs", seg_nris )

#==
Splits and Mergers
==#
println("")
println("FINDING SPLITS AND MERGERS")

splits_fname = "$(output_prefix)_splits.csv"
mergers_fname = "$(output_prefix)_mergers.csv"

@time om = Drivers.h5_file_om( comparison_seg, seg_fname, overlap_chunk_shape )
@time splits, mergers = Drivers.splits_and_mergers(om)

num_splits  = [ length(v) for v in values(splits) ]
num_mergers = [ length(v) for v in values(mergers) ]


RE.write_map_file( splits_fname, splits )
RE.write_map_file( mergers_fname, mergers )

h5write( score_h5, "num_splits", num_splits )
h5write( score_h5, "num_mergers", num_mergers )

