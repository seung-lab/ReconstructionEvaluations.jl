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
General SBM Utility Functions
==========================================#

"""

    fill_G!(G::SparseMatrixCSC, g, dists, dir)

  Fills the graph matrix with edges depending upon the group
distributions within dists. Sampling from the distribution at
index `[i,j]` should instantiate an edge/multiedge between
a node in group `i` and a node in group `j`.
"""
function fill_G!(G::SparseMatrixCSC, g, dists, dir)

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
    if !dir  G[j,i] = v  end
  end

end


"""

    fill_degcorr_G!(G::SparseMatrixCSC, g, dists, dir)

  Fills the graph matrix with edges depending upon the group
distributions within dists. Sampling from the distribution at
index `[i,j]` should instantiate an edge/multiedge between
a node in group `i` and a node in group `j`.
"""
function fill_degcorr_G!(G::SparseMatrixCSC, g, dists, dir)
  0#stub
end


function randomize_g(g, group_types)

  rand_g = zeros(Int,length(g))

  group_to_type = Dict();
  for (i,t) in enumerate(group_types)
    for group in t
      group_to_type[group] = i
    end
  end

  for i in eachindex(g)
    rand_g[i] = rand(group_types[group_to_type[g[i]]])
  end

  rand_g
end

randomize_g!(sbm::SBM) = setgroups(sbm, randomize_g(sbm.g, sbm.t))


"""
Finds the valid cluster pairs to evaluate for the likelihood fn
"""
function assemble_pairs(gtypes, directed)

  @assert length(gtypes) in [1,2] "only full or bipartite graphs supported"

  pairs = Tuple{Int,Int}[] #init
  if length(gtypes) == 2 && directed #directed bipartite graph
    pairs12 = [(r,s) for r in gtypes[1], s in gtypes[2]][:]
    pairs21 = [(r,s) for r in gtypes[2], s in gtypes[1]][:]
    pairs = vcat(pairs12,pairs21)

  elseif length(gtypes) == 2 #undirected bipartite
    pairs = [(r,s) for r in gtypes[1], s in gtypes[2]][:]

  elseif directed #directed full graph
    pairs = [(r,s) for r in gtypes[1], s in gtypes[1]][:]

  else #undirected full graph
    gs = gtypes[1]; ng = length(gs)
    for i in 1:ng, j in i+1:ng
      push!(pairs,(gs[i],gs[j]))
    end
  end

  pairs
end


end #module SBMs
