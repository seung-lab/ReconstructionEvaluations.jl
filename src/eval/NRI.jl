#!/usr/bin/env julia

module NRI

import ..ReconstructionEvaluations
const RE = ReconstructionEvaluations;

"""

   nri( om::SparseMatrixCSC; correct=true )

Implementation of the Neural Reconstruction Index. Incorporates
the correction for false positive values if "correct" is true.
"""
function nri( om::SparseMatrixCSC; correct=true )

  TP, segTP = compute_TPs( om )
  FP, segFP = compute_FPs( om; correct=correct )
  FN, segFN = compute_FNs( om )

  
  NRI = nri( TP, FP, FN )
  segNRI = nri( segTP, segFP, segFN )

  segNRIw = nri_weight( segTP, segFP, segFN )

  NRI, segNRI, segNRIw
end


function nri( om::Array; correct=true )
  nri( sparse(om); correct=correct )
end


function nri( TP, FP, FN )
  2*TP ./ (2*TP + FP + FN)
end


function nri( TP::SparseVector, FP::SparseVector, FN::SparseVector )

  inds = find(TP); #if a segment has no TP's, segNRI=0
  res = sparsevec(Int[],Float64[],length(TP))

  for i in inds res[i] = (2*TP[i]) / (2*TP[i] + FP[i] + FN[i]) end

  res
end


function nri( table1::AbstractArray, table2::AbstractArray; correct=true )
  count_table, A_to_inds, B_to_inds = RE.build_count_table(table1,table2)

  NRI, segNRI, segNRIw = nri( count_table; correct=correct )

  res_segNRI  = sparsevec( Int[], Float64[], maximum(keys(A_to_inds))+1 )
  res_segNRIw = sparsevec( Int[], Float64[], maximum(keys(A_to_inds))+1 )
  for (k,v) in A_to_inds 
      res_segNRI[k] = segNRI[v] 
      res_segNRIw[k] = segNRIw[v]
  end

  NRI, res_segNRI, res_segNRIw
end


function nri( fname1::AbstractString, fname2::AbstractString )

  @assert isfile(fname1) && isfile(fname2)

  table1, table2 = RE.load_edges(fname1), RE.load_edges(fname2)

  nri( table1, table2 )
end


"""

    compute_TPs( om, offset=true )

Counts the number of true positive paths within each
segment in a network specified by a sparse overlap matrix,
and summarizes their total.

Offset indicates whether segment ids are offset by 1 to include
synapse "insertions" and deletions. This feature is not fully implemented
yet.
"""
function compute_TPs( om, offset=true )
  
  rs, cs = findn(om); vs = nonzeros(om);

  TPs = choosetwo(vs);
  segTPs = sparsevec(Int[],Int[],size(om,1));

  oT = one(eltype(rs)); 
  for (r,c,tp) in zip(rs,cs,TPs)

    if r == oT continue end
    if c == oT continue end

    segTPs[r] += tp
  end
  
  sum(segTPs), segTPs
end


"""

    compute_FPs( om, offset=true; correct=true )

Counts the number of false positive paths within each
segment in a network specified by a sparse overlap matrix,
and summarizes their total.

offset indicates whether segment ids are offset by 1 to include
synapse "insertions" and deletions. This feature is not fully implemented
yet.

correct indicates whether to fully penalize false positives (unlike within
the first draft of MATLAB nri code). The false setting is meant to be
used as a comparison
"""
function compute_FPs( om, offset=true; correct=true )
  
  rs, cs = findn(om); vs = nonzeros(om);

  sum_over_cols = sparsevec(Int[],Int[],size(om,2))
  for (c,v) in zip(cs, vs) sum_over_cols[c] += v end

  #needs to be a float to account for attributing
  # mergers to gt segments
  segFPs = sparsevec(Int[],Float64[],size(om,1))

  oT = one(eltype(rs))
  for (r,c,v) in zip(rs,cs,vs)

    if c == oT continue end

    other_count = sum_over_cols[c] - v
    segFPs[r] += (v*other_count) / 2

    #fully accounting for synapse insertions (if using the correct vers)
    if r == oT && correct segFPs[r] += choosetwo(v) end
  end

  sum(segFPs), segFPs
end


"""

    compute_FNs( om, offset=true )

Counts the number of false negative paths within each
segment in a network specified by a sparse overlap matrix,
and summarizes their total.

offset indicates whether segment ids are offset by 1 to include
synapse "insertions" and deletions. This feature is not fully implemented
yet.

correct indicates whether to fully penalize false positives (unlike within
the first draft of MATLAB nri code). The false setting is meant to be
used as a comparison
"""
function compute_FNs( om, offset=true )
  
  rs, cs = findn(om); vs = nonzeros(om);

  sum_over_rows = sparsevec(Int[],Int[],size(om,1))
  for (r,v) in zip(rs, vs) sum_over_rows[r] += v end

  segFNs = sparsevec(Int[],Float64[],size(om,1))

  oT = one(eltype(rs))
  for (r,c,v) in zip(rs,cs,vs)

    if r == oT continue end

    other_count = sum_over_rows[r] - v
    segFNs[r] += (v*other_count) / 2

    #accounting for synapse deletions
    if c == oT segFNs[r] += choosetwo(v) end
  end

  sum(segFNs), segFNs
end


"""

    nri_weight( segTP, segFP, segFN )

Finds the weight for each segment s.t. the full network
NRI is a weighted sum of each individual NRI values. This value
is equal to the sum of "positives" (TP+FP) and "negatives" (TP+FN)
for each segment.
"""
function nri_weight( segTP, segFP, segFN )

  total_weight = 2*sum(segTP) + sum(segFP) + sum(segFN)

  is = Set(find(segTP)); union!(is, find(segFP)); union!(is, find(segFN));

  res = sparsevec(Int[],Float64[],length(segTP))

  for i in is res[i] = (2*segTP[i] + segFP[i] + segFN[i]) / total_weight end

  res
end


"""

    nri_by_class( seg_nri, seg_nriw, class_map )
"""
function nri_by_class( seg_nri, seg_nriw, class_map )

  is = find(seg_nriw)

  class_nri = Dict( k => 0. for k in unique(values(class_map)) )
  class_w   = Dict( k => 0. for k in unique(values(class_map)) )

  for i in is
    if !haskey(class_map,i) continue end

    class_w[class_map[i]] += seg_nriw[i]
  end

  for i in is
    if !haskey(class_map,i) continue end
    class = class_map[i]

    class_nri[class] += (seg_nri[i] * seg_nriw[i]) / class_w[class]
  end

  class_nri, class_w
end

#Utility fns
choosetwo(x) = x * ((x-1)/2)
choosetwo!(x) = for i in eachindex(x) x[i] *= (x[i]-1)/2 end
choosetwo(x::Array) = [ v*((v-1)/2) for v in x ]


end #module end
