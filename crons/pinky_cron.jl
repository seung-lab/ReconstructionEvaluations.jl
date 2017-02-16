#!/usr/bin/env julia

import ReconstructionEvaluations
import ReconstructionEvaluations.Cron.Synaptor


seg_fname = ARGS[1]

y,m,d = Dates.yearmonthday(now());
output_prefix = abspath("archive/pinky_cron_$(d)_$(m)_$(y)")



cfg = Synaptor.make_gc_cfg(seg_fname, output_prefix)

#Synaptor.run_cfg_file(cfg)

#removing outputs which we don't need
Synaptor.rm_mapping_file(output_prefix)
Synaptor.rm_seg_file(output_prefix)


edge_filename = "$(output_prefix)_edges.csv"
cons_edge_filename = "$(output_prefix)_edges_cons.csv"

Synaptor.rm_duplicates( edge_filename, cons_edge_filename )

