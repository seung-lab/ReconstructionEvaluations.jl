module sbm 

abstract SBM

export SBM
export loglikelihood, computeparams
export considermove, enactmove
export getindices, getgroups


function loglikelihood(sbm::SBM)
  error("loglikelihood not implemented for type $(typeof(sbm))")
end


function computeparams(sbm::SBM)
  error("computeparams not implemented for type $(typeof(sbm))")
end


function considermove(sbm::SBM)
  error("considermove not implemented for type $(typeof(sbm))")
end


function enactmove(sbm::SBM)
  error("enactmove not implemented for type $(typeof(sbm))")
end


function getindices(sbm::SBM)
  error("getindices not implemented for type $(typeof(sbm))")
end


function getgroups(sbm::SBM)
  error("getgroups not implemented for type $(typeof(sbm))")
end

function fill_G!(G,g,dists)

  @assert size(G,1) == size(G,2) "G must be a square matrix"

  n = size(G,1)

  for i in 1:n, j in 1:n

    gi,gj = g[i], g[j]
    dist = dists[gi,gj]

    v = rand(dist)
    if v == 0 continue end

    G[i,j] = v
  end

end

end #module SBM
