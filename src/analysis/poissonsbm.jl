module PoissonSBM

include("SBM.jl")
using .sbm

using Distributions

#for now, I'll assume that the model is:
#  - directed
#  - bipartite
#  - degree corrected
type PoisSBM <: SBM

  G::SparseMatrixCSC
  g::Vector{Int}
  t::Tuple{Vector{Int},Vector{Int}}
  
end


function make_dummy( N=40 )

  G = spzeros(UInt8,N,N)
  #3/4 axon, 1/4 dend; 1/2 g1
  t = ([1,2],[3,4]) #1&2 -> axon, 3&4 -> dend
  g = ones(Int,(N,))
  for i in eachindex(g)
    if     i > round(Int,7*N/8)  g[i] = 4
    elseif i > round(Int,6*N/8)  g[i] = 3
    elseif i > round(Int,3*N/8)  g[i] = 2
    else                         g[i] = 1
    end
  end

  p = [0  0  8  6;
       0  0  1  1;
       0  0  0  0;
       0  0  0  0];

  dists = [Distributions.Poisson(p[i,j]) for i in 1:4, j in 1:4]

  sbm.fill_G!(G, g, dists)

  PoisSBM(G,g,t)
end


"""
Computing everything you need to compute likelihood and consider
moves
"""
function computeparams(sbm::PoisSBM, g=nothing)

  if g == nothing g = sbm.g end

  node_indeg, node_outdeg = compute_node_degrees(sbm, g)

  cl_indeg, cl_outdeg, cl_edges = group_degrees(node_indeg, node_outdeg, g)

  Dict( "node_indeg"=>node_indeg,
        "node_outdeg"=>node_outdeg,
        "cluster_indeg"=>cl_indeg,
        "cluster_outdeg"=>cl_outdeg,
        "cluster_edge_counts"=>cl_edges )
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


function considermoves(sbm::PoisSBM, i, g=nothing, params=nothing)

  if g == nothing     g = sbm.g                    end
  if params==nothing  params=computeparams(sbm,g)  end

  gi = g[i]

  g_type = collect(filter( x -> gi in x, sbm.t ))
  @assert length(g_type) == 1

  moves = Int[]
  logliks = Float64[]

  for group in g_type[1]

    if gi == group continue end

    push!(moves,group)

    new_params = tweak_params(params, i, gi, group)
    
    push!(logliks, loglikelihood(sbm, new_params))
  end
  
  moves, logliks
end


function tweak_params(params, i, orig_group, new_group)
  
  nbor_incls = params["node_indeg"][i,:]
  nbor_outcls = params["node_outdeg"][i,:]

  cl_edges = copy(params["cluster_edge_counts"])
  
  for cl in eachindex(nbor_incls)
    cl_edges[orig_group,cl] -= nbor_outcls[cl]
    cl_edges[cl,orig_group] -= nbor_incls[cl]

    cl_edges[new_group,cl]  += nbor_outcls[cl]
    cl_edges[cl,new_group]  += nbor_incls[cl]
  end

  Dict( "cluster_indeg"  => sum(cl_edges,1),
        "cluster_outdeg" => sum(cl_edges,2),
        "cluster_edge_counts"  => cl_edges )
end


function loglikelihood(sbm::PoisSBM, g=nothing, ps=nothing)
  
  if g == nothing   g = sbm.g                end
  if ps == nothing  ps = computeparams(sbm)  end
  
  cl_indeg    = ps["cluster_indeg"]
  cl_outdeg   = ps["cluster_outdeg"]
  edge_counts = ps["cluster_edge_counts"]

  ll = 0
  for r in sbm.t[1], s in sbm.t[2]

    cl_out_r = cl_outdeg[r]
    cl_in_s  = cl_indeg[s]

    println(cl_out_r)
    println(cl_in_s)

    if cl_out_r*cl_in_s == 0  continue  end

    m_rs = edge_counts[r,s]
    println(m_rs)
    ll += m_rs*log(m_rs/(cl_out_r*cl_in_s))
  end

  ll
end

end #module PoissonSBM
