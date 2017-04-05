module SBMs

abstract SBM

export SBM
export loglikelihood, computeparams
export considermoves, enactmove
export getindices, getgroups
export setgroups


"""

    loglikelihood(sbm::SBM, g=nothing, ps=nothing)

  Computes the loglikelihood for a model at the cluster state `g`, or given the
model parameters `ps`.

  If a `ps` argument is passed, the `g` variable is ignored.
If neither a `g` nor a `ps` is passed, g is taken from the internal SBM state,
and the parameters are computed from that state.
"""
function loglikelihood(sbm::SBM, g=nothing, ps=nothing)
  error("loglikelihood not implemented for type $(typeof(sbm))")
end

"""

    computeparams(sbm::SBM, g=nothing)

  Computes the model parameters for a model at the cluster state `g`.

  If no `g` variable is passed, it's taken from the internal model state.
"""
function computeparams(sbm::SBM, g=nothing, ps=nothing)
  error("computeparams not implemented for type $(typeof(sbm))")
end


"""

    updateparams!(sbm::SBM, ps, old_g, g=nothing)

  Sometimes, it can be quicker to update parameters given the group changes
instead or recomputing them. This performs an update step, or defaults to
recomputation.

  If no `g` variable is passed, it's taken from the internal model state.
"""
function updateparams!(sbm::SBM, ps, old_g, g=nothing)
  computeparams(sbm,g)
end


"""

    considermoves(sbm::sbm, i, g=nothing, ps=nothing; forcemove=true)

  Computes the loglikelihood for all possible moves of node `i` starting
from cluster state `g` or parameters `ps`.

  If a `ps` argument is passed, the `g` variable is ignored.
If neither a `g` nor a `ps` is passed, g is taken from the internal SBM state,
and the parameters are computed from that state.

  If `forcemove`, then only the cluster assignments not equal to the current
setting are considered.
"""
function considermoves(sbm::SBM, i, g=nothing, ps=nothing; forcemove=true)
  error("considermove not implemented for type $(typeof(sbm))")
end

"""

    bestmove(sbm::SBM, i, g=nothing, ps=nothing; forcemove=true)

Selects the move which maximizes the loglikelihood for a given model.

  If `forcemove`, then only the cluster assignments not equal to the current
setting are considered, and the move selected could be one which least decreases
the ll.
"""
function bestmove(sbm::SBM, i, g=nothing, ps=nothing; forcemove=true)
  moves, logliks = considermoves(sbm, i, g, ps; forcemove=forcemove)
  maxll, maxi = findmax(logliks)

  moves[maxi], maxll
end

"""

    enactmove(sbm::SBM, i, new_group)

Changes the internal cluster state of `sbm` by a single move.

See `setgroups` for batch editing
"""
enactmove(sbm::SBM, i, new_group) = sbm.g[i] = new_group


getindices(sbm::SBM) = 1:size(sbm.G,1)
getgroups(sbm::SBM) = copy(sbm.g)
getgroups(sbm::SBM, i) = sbm.g[i]


"""
    setgroups(sbm::SBM, g)

  Sets the cluster state to `g`
"""
function setgroups(sbm::SBM, g)

  @assert typeof(g) == typeof(sbm.g)
  @assert length(g) == length(sbm.g)

  sbm.g = copy(g)

end

#==========================================
Utility Functions
==========================================#

"""

    fill_G!(G::SparseMatrixCSC, g, dists)

  Fills the graph matrix with edges depending upon the group
distributions within dists. Sampling from the distribution at
index `[i,j]` should instantiate an edge/multiedge between
a node in group `i` and a node in group `j`.
"""
function fill_G!(G::SparseMatrixCSC, g, dists)

  @assert size(G,1) == size(G,2) "G must be a square matrix"
  num_groups = length(unique(g))
  @assert size(dists) == (num_groups,num_groups)


  n = size(G,1)

  for i in 1:n, j in 1:n

    gi,gj = g[i], g[j]
    dist = dists[gi,gj]

    v = rand(dist)
    if v == 0 continue end

    G[i,j] = v
  end

end


end #module SBMs
