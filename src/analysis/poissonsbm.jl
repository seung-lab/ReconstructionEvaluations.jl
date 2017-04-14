module PoissonSBM


using ..SBMs


export PoisSBM


import Distributions


type PoisSBM <: SBM

  G::SparseMatrixCSC
  g::Vector{Int}
  t::Vector{Vector{Int}}
  dir::Bool
  degcorr::Bool

end

#Each "ps" is an Any[] with the following fields (Dicts were REALLY slow...)
@enum PARAMFIELDS CL_COUNTS=1 NODE_INDEG=2 NODE_OUTDEG=3 CL_INDEG=4 CL_OUTDEG=5 CL_EDGE_COUNTS=6

function make_dummy( N=40, dir=false, degcorr=true )

  G = spzeros(UInt8,N,N)
  #3/4 axon, 1/4 dend; 1/2 g1
  t = [[1,2],[3,4]] #1&2 -> axon, 3&4 -> dend
  g = ones(Int,(N,))

  for i in eachindex(g)
    if     i > round(Int,7*N/8)  g[i] = 4
    elseif i > round(Int,6*N/8)  g[i] = 3
    elseif i > round(Int,3*N/8)  g[i] = 2
    else                         g[i] = 1
    end
  end

  p = [0  0  2  2;
       0  0  1  3;
       0  0  0  0;
       0  0  0  0];

  #NOTE: dummy model currently doesn't include much degree variation
  dists = [Distributions.Poisson(p[i,j]) for i in 1:4, j in 1:4];

  SBMs.fill_G!(G, g, dists, dir)

  PoisSBM(G,g,t,dir,degcorr)
end


function make_full_dummy( N=40, dir=false, degcorr=false )

  G = spzeros(UInt8,N,N)

  t = [[1,2]]
  g = zeros(Int,(N,))

  for i in eachindex(g)
    if i > round(Int,3*N/4)  g[i] = 2
    else                     g[i] = 1
    end
  end

  p = [1  5;
       2  1]

  #NOTE: dummy model currently doesn't include much degree variation
  dists = [Distributions.Poisson(p[i,j]) for i in 1:2, j in 1:2]

  SBMs.fill_G!(G, g, dists, dir)

  PoisSBM(G,g,t,dir,degcorr)
end


function SBMs.computeparams(sbm::PoisSBM, g=nothing)

  if g == nothing  g = sbm.g  end

  cluster_counts = count_groups(g)

  node_indeg, node_outdeg = compute_node_degrees(sbm, g)

  cl_indeg, cl_outdeg, cl_edges = group_degrees(node_indeg, node_outdeg, g)

  Any[cluster_counts, node_indeg, node_outdeg,
   cl_indeg, cl_outdeg, cl_edges]
end


function count_groups(g)

  max_group = maximum(g)

  counts = zeros(Int,max_group)

  for v in g  counts[v] += 1  end

  counts
end


function SBMs.updateparams!(sbm::PoisSBM, ps, old_g, g=nothing)

  if g == nothing  g = sbm.g  end

  update_group_counts!(ps, g)
  update_node_degrees!(sbm, ps, old_g, g)

  cl_indeg, cl_outdeg, cl_edges = group_degrees(ps[Int(NODE_INDEG)],
                                                ps[Int(NODE_OUTDEG)],g)

  ps[Int(CL_INDEG)]  = cl_indeg;
  ps[Int(CL_OUTDEG)] = cl_outdeg;
  ps[Int(CL_EDGE_COUNTS)] = cl_edges;

end


function update_group_counts!(ps,g)

  #recomputing is as fast as updating in this case
  ps[Int(CL_COUNTS)] = count_groups(g)

end


function update_node_degrees!(sbm::PoisSBM, ps, old_g, g)

  @assert typeof(old_g) == typeof(g)
  @assert size(old_g)   == size(g)

  node_indeg = ps[Int(NODE_INDEG)]
  node_outdeg = ps[Int(NODE_OUTDEG)]

  for i in eachindex(g)
    curr_group, old_group = g[i],old_g[i]

    if curr_group == old_group  continue  end

    senders, sender_vs = findnz(sbm.G[:,i])
    receivers, rec_vs  = findnz(sbm.G[i,:])

    for (s,sv) in zip(senders, sender_vs)
      node_outdeg[s,old_group]  -= sv
      node_outdeg[s,curr_group] += sv
    end

    for (r,rv) in zip(receivers,rec_vs)
      node_indeg[r,old_group] -= rv
      node_indeg[r,curr_group] += rv
    end

  end

end


function compute_node_degrees(sbm, g=nothing)

  if g == nothing g = sbm.g end

  G = sbm.G
  n = size(G,1)
  max_group = maximum(g)

  #assumes g is 1:max_group
  node_indeg  = zeros(Int,(n,max_group))
  node_outdeg = zeros(Int,(n,max_group))

  rows = rowvals(G)
  vals = nonzeros(G)
  for i in 1:n, j in nzrange(G,i)
    r = rows[j]; v = vals[j]

    node_indeg[i,g[r]] += v
    node_outdeg[r,g[i]] += v
  end

  node_indeg, node_outdeg
end


function group_degrees(node_indeg, node_outdeg, g)

  max_group = maximum(g)

  cl_edges = zeros(Int,max_group,max_group)

  sx,sy = size(node_outdeg)
  for j in 1:sy, i in 1:sx
    if node_outdeg[i,j] == 0 continue end
    cl_edges[g[i],j] += node_outdeg[i,j]
  end

  sum(cl_edges,1), sum(cl_edges,2), cl_edges
end


function SBMs.considermoves(sbm::PoisSBM, i, g=nothing, ps=nothing; forcemove=true)

  if g == nothing   g = sbm.g                end
  if ps == nothing  ps=computeparams(sbm,g)  end

  gi = g[i]

  gi_type = gi in sbm.t[1] ? sbm.t[1] : sbm.t[2]
  # g_type = collect(filter( x -> gi in x, sbm.t ))
  # @assert length(g_type) == 1 "Group exists within multilple types"

  moves = Int[]
  logliks = Float64[]

  for group in gi_type #g_type[1]

    if gi == group && forcemove  continue  end

    push!(moves,group)

    new_params = tweak_params(ps, i, gi, group)

    push!(logliks, loglikelihood(sbm, nothing, new_params))
  end

  moves, logliks
end


function tweak_params(ps, i, orig_group, new_group)

  cluster_counts = copy(ps[Int(CL_COUNTS)])

  cluster_counts[orig_group] -= 1
  cluster_counts[new_group]  += 1

  nbor_incls = ps[Int(NODE_INDEG)][i,:]
  nbor_outcls = ps[Int(NODE_OUTDEG)][i,:]

  cl_edges = copy(ps[Int(CL_EDGE_COUNTS)])

  for cl in eachindex(nbor_incls)
    cl_edges[orig_group,cl] -= nbor_outcls[cl]
    cl_edges[cl,orig_group] -= nbor_incls[cl]

    cl_edges[new_group,cl]  += nbor_outcls[cl]
    cl_edges[cl,new_group]  += nbor_incls[cl]
  end

  cl_indeg = sum(cl_edges,1)
  cl_outdeg = sum(cl_edges,2)

  Any[ cluster_counts, nothing, nothing,
       cl_indeg, cl_outdeg, cl_edges ]
end


function SBMs.loglikelihood(sbm::PoisSBM, g=nothing, ps=nothing)

  if g == nothing   g = sbm.g                  end
  if ps == nothing  ps = computeparams(sbm,g)  end

  cl_count    = ps[Int(CL_COUNTS)]
  cl_indeg    = ps[Int(CL_INDEG)]
  cl_outdeg   = ps[Int(CL_OUTDEG)]
  edge_counts = ps[Int(CL_EDGE_COUNTS)]

  ll = 0

  pairs = SBMs.assemble_pairs(sbm.t, sbm.dir)
  for (r,s) in pairs

    denom = 0

    if sbm.degcorr
      cl_out_r = cl_outdeg[r]
      cl_in_s  = cl_indeg[s]
      denom = cl_out_r * cl_in_s
    else
      n_r, n_s = cl_count[r], cl_count[s]
      denom = n_r*n_s
    end

    if denom == 0  continue  end

    m_rs = edge_counts[r,s]

    ll += m_rs*log(m_rs/(denom))
  end

  ll
end

#Not ready yet
#function compute_prob_matrix(sbm::PoisSBM, g=nothing, ps=nothing)
#
#  if g == nothing   g = sbm.g                  end
#  if ps == nothing  ps = computeparams(sbm,g)  end
#end


end #module PoissonSBM
