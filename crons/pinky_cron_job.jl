#!/usr/bin/env julia

include("../src/ReconstructionEvaluations.jl");

const RE = ReconstructionEvaluations
const CronUtils = RE.CronUtils
const Synaptor  = CronUtils.Synaptor
const Drivers   = CronUtils.Drivers
const NRI       = RE.NRI

using HDF5


seg_fname = ARGS[1]
output_prefix = ARGS[2]

append_score = false 

#-------------------------
gt_seg = "data/pinky_golden_cube_021717.h5"
gt_edges = "data/pinky_golden_cube_021717_edges.csv"
gt_semmap = "data/pinky_golden_cube_021717_semmap.csv"

score_record = joinpath(dirname(output_prefix),"NRI_curve.h5")

dist_thr = 1000
res = [4,4,40]

overlap_chunk_shape = [1024,1024,128]
#-------------------------

#Defining output filename
score_h5 = "$(output_prefix)_scores.h5"

#==
Running Synaptor postprocessing
==#
println("RUNNING SYNAPTOR POSTPROCESSING")

cfg = Synaptor.make_gc_cfg(seg_fname, output_prefix)

edge_fname = Drivers.run_synaptor_cfg( cfg, output_prefix, dist_thr, res )
#edge_fname = "/usr/people/nturner/seungmount/research/metric_cronbot/pinky/pinky_cron_02_03_2017_edges_cons.csv"


#==
Computing NRI scores
==#
println("")
println("COMPUTING NRI")

@time semmap = RE.load_semmap(gt_semmap)

@time full_nri, seg_nris, seg_nriw = NRI.nri(gt_edges, edge_fname)
@time full_pnri, pseg_nris, pseg_nriw = NRI.nri(edge_fname, gt_edges)#running a second time for proposed segments
println("NRI: $(full_nri)")
@time class_NRIs, class_weight = NRI.nri_by_class( seg_nris, seg_nriw, semmap )

println("Class NRI: $(class_NRIs)")
println("Class Weight: $(class_weight)")


seg_ids, seg_nris = CronUtils.spvec_to_arrays(seg_nris)
seg_ids, seg_nriw = CronUtils.spvec_to_arrays(seg_nriw)

pseg_ids, pseg_nris = CronUtils.spvec_to_arrays(pseg_nris)
pseg_ids, pseg_nriw = CronUtils.spvec_to_arrays(pseg_nriw)

h5write( score_h5, "NRI"       , full_nri       ) 
h5write( score_h5, "seg_NRIs"  , seg_nris       )
h5write( score_h5, "seg_NRIws" , seg_nriw       )
h5write( score_h5, "seg_ids"   , seg_ids        )
h5write( score_h5, "ax_NRI"    , class_NRIs[2]  )
h5write( score_h5, "dend_NRI"  , class_NRIs[3]  )
h5write( score_h5, "ax_NRIw"   , class_weight[2])
h5write( score_h5, "dend_NRIw" , class_weight[3])
h5write( score_h5, "pseg_NRIs" , pseg_nris      )
h5write( score_h5, "pseg_NRIws", pseg_nriw      )
h5write( score_h5, "pseg_ids"  , pseg_ids       )

if append_score CronUtils.append_score( full_nri, score_record ) end

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

