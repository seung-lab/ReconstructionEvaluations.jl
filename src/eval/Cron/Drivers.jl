#!/usr/bin/env julia

# module Drivers

# import ReconstructionEvaluations
# import ReconstructionEvaluations.Cron.Synaptor
# import ReconstructionEvaluations.io

# const = ReconstructionEvaluations


function run_synaptor_cfg( cfg, output_prefix, dist_thr, res,
  keep_seg=false, keep_mapping=false )

  Synaptor.run_cfg_file(cfg)

  if !keep_seg Synaptor.rm_seg_file(output_prefix) end
  if !keep_mapping Synaptor.rm_mapping_file(output_prefix) end

  edge_filename = "$(output_prefix)_edges.csv"
  cons_edge_filename = "$(output_prefix)_edges_cons.csv"

  #The string interpolation is a bit funky, so the resolution
  # vector should be written as a string
  Synaptor.rm_duplicates( edge_filename, cons_edge_filename, dist_thr, string(res) )

  cons_edge_filename
end


"""

    h5_file_overlap_matrix( seg1fname, seg2fname, chunk_shape, verb=true )

Finds the overlap matrix for two h5 segmentations as a sparse matrix
"""
function h5_file_om( seg1fname, seg2fname, chunk_shape, verb=true )

  seg1 = io.read_h5(seg1fname, false)
  seg2 = io.read_h5(seg2fname, false)

  impl_om = overlap_in_chunks(seg1, seg2, chunk_shape, verb)

  om_from_impl(impl_om)
end


"""
Returns the number of splits and mergers for each segment in the rows of the
overlap matrix
"""
function splits_and_mergers( om )
  
  rs, cs = findn(om)

  splits = Dict{eltype(rs),Vector{eltype(cs)}}();
  mergers = Dict{eltype(cs),Vector{eltype(rs)}}();

  for i in eachindex(rs)
    r,c = rs[i], cs[i]

    if !haskey(splits,r) splits[r] = [c]
    else push!(splits[r],c)
    end

    if !haskey(mergers,c) mergers[c] = [r]
    else push!(mergers[c],r)
    end
    
  end

  splits  = filter( (k,v) -> length(v) > 1, splits )
  mergers = filter( (k,v) -> length(v) > 1, mergers )

  splits, mergers
end



# end#module end
