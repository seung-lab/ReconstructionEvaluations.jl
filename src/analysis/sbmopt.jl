
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
    #print("\rEpoch #$n")
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
    #print("\rEpoch #$n")
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


function KLlikeopt!(sbm::SBM, nepoch=100)

  lls = [];

  for n in 1:nepoch
    print("\rEpoch #$n")

    ps = SBMs.computeparams(sbm)
    #keeping two copies so we can update parameters later
    g  = SBMs.getgroups(sbm)
    last_g = copy(g)

    epoch_moves = Tuple{Int,Int}[];
    epoch_lls = Float64[];

    start_ll = SBMs.loglikelihood(sbm,nothing,ps)

    to_move = IntSet(SBMs.getindices(sbm))

    while !isempty(to_move)

      vertex, move, ll = find_best_move_overall(sbm,g,ps, to_move)

      #enacting move for this epoch
      g[vertex] = move
      SBMs.updateparams!(sbm,ps,last_g,g)
      last_g[vertex] = move

      #bookkeeping
      delete!(to_move, vertex)
      push!(epoch_moves, (vertex,move))
      push!(epoch_lls, ll)

    end #while !empty(to_move)

    max_ll, max_i = findmax(epoch_lls)

    if start_ll >= max_ll  break  end

    #replaying changes up to max_ll over the epoch
    for i in 1:max_i
      v, cl = epoch_moves[i]
      SBMs.enactmove(sbm,v,cl)
      #recording relevant lls
      push!(lls, epoch_lls[i])
    end

  end

  lls
end


function find_best_move_overall(sbm,g,ps, candidates)

  max_ll = -Inf; max_vertex = 0; max_move = 0;

  for i in candidates

    best_move_i, best_ll_i = SBMs.bestmove(sbm,i,g,ps;forcemove=true)

    if best_ll_i > max_ll
      max_ll = best_ll_i
      max_vertex = i
      max_move = best_move_i
    end

  end

  max_vertex, max_move, max_ll
end


function multiple_trials!(sbm::SBM, opt_fn::Function, num_trials=10, nepochs=100)

  best_lls = []
  best_groups = []
  final_lls = []
  best_final_ll = -Inf
  final_groups = []

  for t in 1:num_trials

    if t == 1
      print("\rTrial $t")
    else
      print("\rTrial $t, Last Trial Time: $(round(toq(),3)) seconds")
    end
    tic();

    SBMs.randomize_g!(sbm)

    trial_lls = opt_fn(sbm,nepochs)

    push!(final_lls, trial_lls[end])
    push!(final_groups, SBMs.getgroups(sbm))

    if trial_lls[end] > best_final_ll
      best_lls = trial_lls
      best_groups = SBMs.getgroups(sbm)
    end
  end

  toq();

  final_lls, final_groups, best_lls, best_groups
end


end #SBMopt
