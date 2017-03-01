#!/usr/bin/env julia

module NRI


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


  NRI, segNRI, segTP, segFP, segFN
end


function nri( om::Array; correct=true )
  nri( sparse(om); correct=correct )
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


function nri( TP, FP, FN )
  2*TP ./ (2*TP + FP + FN)
end


#Utility fns
choosetwo(x) = x * ((x-1)/2)
choosetwo!(x) = for i in eachindex(x) x[i] *= (x[i]-1)/2 end
choosetwo(x::Array) = [ v*((v-1)/2) for v in x ]


end #module end
