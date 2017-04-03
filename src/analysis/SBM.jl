module SBM

abstract SBM

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
  

end #module SBM
