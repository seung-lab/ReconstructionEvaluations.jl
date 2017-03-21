#!/usr/bin/env julia

using ...ReconstructionEvaluations
using ..HDF5

const RE = ReconstructionEvaluations


function spvec_to_arrays(X::SparseVector)
  X = dropzeros(X)
  find(X), nonzeros(X)
end


function fill_array_indices( is1, vs1, is2, vs2 )

  is = sort(union(is1,is2))

  l1, l2 = length(vs1), length(vs2)
  v1, v2 = zeros(eltype(vs1),length(is)), zeros(eltype(vs2),length(is))

  p1,p2 = 1,1# current "pointer" to vs1&2
  for (i,v) in enumerate(is)
    if p1 <= l1 && v == is1[p1]
      v1[i] = vs1[p1]
      p1 += 1
    end

    if p2 <= l2 && v == is2[p2]
      v2[i] = vs2[p2]
      p2 += 1
    end
  end

  is, v1, v2
end


function append_score( score, score_record )
  scores = HDF5.h5read(score_record, "/main")

  push!(scores, score)

  RE.write_h5(scores, score_record)
end
