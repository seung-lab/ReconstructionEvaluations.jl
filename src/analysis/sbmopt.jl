
module SBMopt

using ..SBMs

export simpleopt!, fasteropt!, TMopt!, KLopt!
export multiple_trials

"""

    simpleopt!(sbm::SBM, nepoch=100)

Performs the most simple optimization procedure I could think of
(direct hill climbing)
"""
function simpleopt!(sbm::SBM, nepoch=100)

  lls = []

  for n in 1:nepoch
    print("\rEpoch #$n")
    ll = 0

    for i in shuffle(SBMs.getindices(sbm))

      next_move, ll = SBMs.bestmove(sbm,i; forcemove=false)
      SBMs.enactmove(sbm,i,next_move)

      push!(lls,ll)
    end
  end
  println("")

  lls
end


"""
A faster version of simpleopt! using incrementally updated parameters.
The simple version works for smaller graphs (e.g. 40 nodes), but this scales
much better
"""
function fasteropt!(sbm::SBM, nepoch=100)

  lls = []

  for n in 1:nepoch
    print("\rEpoch #$n")
    ll = 0
    ps = SBMs.computeparams(sbm)

    for i in shuffle(SBMs.getindices(sbm))

      next_move, ll = SBMs.bestmove(sbm,i,nothing,ps; forcemove=false)

      old_g = SBMs.getgroups(sbm)
      SBMs.enactmove(sbm,i,next_move)
      if old_g[i] != next_move  SBMs.updateparams!(sbm,ps,old_g)  end

      push!(lls,ll)
    end
  end
  println("")

  lls
end

"""

    TMopt!(sbm::SBM, nepoch=100)

Tommy's optimization algorithm
"""
function TMopt!(sbm::SBM, nepoch=100)

  lls = []

  ps = SBMs.computeparams(sbm)
  for n in 1:nepoch

    groups_start_epoch = SBMs.getgroups(sbm)

    for i in shuffle(SBMs.getindices(sbm))

      next_move, ll = SBMs.bestmove(sbm,i,nothing,ps; forcemove=false)

      old_g = SBMs.getgroups(sbm)
      SBMs.enactmove(sbm,i,next_move)

      if old_g[i] != next_move
        SBMs.updateparams!(sbm,ps,old_g)
        push!(lls,ll)
        break
      end

    end #for i in randperm

    groups_end_epoch = SBMs.getgroups(sbm)
    if minimum( groups_start_epoch .== groups_end_epoch )  break  end

  end #for n in 1:nepoch

  lls
end


function KLopt!(sbm::SBM, nepoch=100)
  0#stub
end


function multiple_trials(sbm::SBM, opt_fn::Function, num_trials=10, nepochs=100)

  start_g = SBMs.getgroups(sbm)

  best_lls = [] 
  final_lls = []
  best_final_ll = -Inf
  final_groups = []

  for t in 1:num_trials

    SBMs.setgroups(sbm,start_g)

    trial_lls = opt_fn(sbm,nepochs)

    push!(final_lls, trial_lls[end])
    push!(final_groups, SBMs.getgroups(sbm))

    if trial_lls[end] > best_final_ll  best_lls = trial_lls  end
  end

  final_lls, final_groups, best_lls
end


end #SBMopt
