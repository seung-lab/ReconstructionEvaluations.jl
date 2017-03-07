#!/usr/bin/env julia

using ...ReconstructionEvaluations
using ..HDF5

const RE = ReconstructionEvaluations


spvec_to_arrays(X::SparseVector) = find(X), nonzeros(X)


function append_score( score, score_record )
  scores = HDF5.h5read(score_record, "/main")

  push!(scores, score)

  RE.write_h5(scores, score_record)
end

