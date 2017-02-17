#!/usr/bin/env julia

import ReconstructionEvaluations
import ReconstructionEvaluations.Cron.Synaptor
const RE = ReconstructionEvaluations

import Drivers

using HDF5
#using Gadfly
#using DataFrames


seg_fname = ARGS[1]
output_prefix = ARGS[2]


#-------------------------
gt_seg = "data/pinky_golden_cube_021717.h5"
gt_edges = "data/pinky_golden_cube_021717_edges.csv"
gt_semmap = "data/pinky_golden_cube_021717_semmap.csv"

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

#edge_fname = Drivers.run_synaptor_cfg( cfg, output_prefix, dist_thr, res )
edge_fname = "$(output_prefix)_edges_cons.csv"

#==
Computing NRI score
==#
println("")
println("COMPUTING NRI")

@time full_nri, seg_nris = RE.compute_nri( edge_fname, gt_edges )


h5write( score_h5, "NRI", full_nri )
h5write( score_h5, "seg_NRIs", seg_nris )

#==
Splits and Mergers
==#
println("")
println("FINDING SPLITS AND MERGERS")

asplits_fname = "$(output_prefix)_axon_splits.csv"
dsplits_fname = "$(output_prefix)_dend_splits.csv"
mergers_fname = "$(output_prefix)_mergers.csv"

@time om = Drivers.h5_file_om( gt_seg, seg_fname, overlap_chunk_shape )
@time splits, mergers = Drivers.splits_and_mergers(om)


semmap = RE.load_semmap( gt_semmap )
axon_splits = filter( (k,v) -> semmap[k] == 2, splits )
dend_splits = filter( (k,v) -> semmap[k] == 3, splits )


num_axon_splits  = [ length(v) for v in values(axon_splits) ]
num_dend_splits  = [ length(v) for v in values(dend_splits) ]
num_mergers = [ length(v) for v in values(mergers) ]


RE.write_map_file( asplits_fname, axon_splits )
RE.write_map_file( dsplits_fname, dend_splits )
RE.write_map_file( mergers_fname, mergers )

h5write( score_h5, "num_axon_splits", num_axon_splits )
h5write( score_h5, "num_dend_splits", num_dend_splits )
h5write( score_h5, "num_mergers", num_mergers )

#==
Plotting
==#

#asplit_plot = "$(output_prefix)_axon_splits.png"
#dsplit_plot = "$(output_prefix)_dend_splits.png"

#asplit_df = DataFrame( Axon_Splits= num_axon_splits )
#dsplit_df = DataFrame( Dend_Splits= num_dend_splits )

#draw(PNG(asplitplot, 8inch, 8inch), plot(asplit_df, x=:Axon_Splits, Geom.histogram))
#draw(PNG(dsplitplot, 8inch, 8inch), plot(dsplit_df, x=:Dend_Splits, Geom.histogram))

