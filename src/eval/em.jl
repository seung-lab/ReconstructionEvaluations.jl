"""
Create per neuron count of neighbor neuron labels

Inputs:
    adj: sparse adjacency matrix (NxN)
    labels: integer list of each neuron's label (Nx1)

Outputs:
    counts: MxN array of count of neighbors per each label
"""
function count_neighbor_labels(adj, labels)
    assert(size(adj,1) == length(labels))
    n = size(adj,1)
    counts = zeros(Int64,2,n)
    rows = rowvals(adj)
    # vals = nonzeros(adj)
    for i in 1:n
        for j in nzrange(adj, i)
            row = rows[j]
            # println(row, i)
            # val = vals[j]
            neighbor_label = labels[i]
            counts[neighbor_label,row] += 1 
        end
    end
    return counts
end

"""
Compile count dicts of connections between labels (accounting for pre & post)

Inputs:
    counts: MxN array of count of neighbors per each label 
        (see count_neighbor_labels)
    labels: Nx1 label assignment of each neuron
    pre_post: Nx1 int classification or pre (1) or post (2)
        (only allow possible connections from pre to post)

Outputs:
    ns: count dict of current label pair connections
    Ns: count dict of total possible label pair connections
    Ns_prepost: count dict of labels classified as pre or post
        indexed by tuple (label id, pre/post id)
"""
function compile_count_dicts(counts::Array, labels::Array, pre_post::Array)
    pairs = []
    for i in [1,2]
        for j in [1,2]
            push!(pairs, (i,j))
        end
    end
    ns = Dict()
    Ns = Dict()
    Ns_prepost = Dict()
    for (a,b) in pairs
        n = sum(counts[b, labels.==a])
        Ns_pre = sum((labels.==a)) #&(pre_post.==1))
        Ns_post = sum((labels.==b)) #&(pre_post.==2))
        N = Ns_pre*Ns_post
        ns[a,b] = n
        Ns[a,b] = N
        Ns_prepost[a,1] = Ns_pre
        Ns_prepost[b,2] = Ns_post
    end
    return ns, Ns, Ns_prepost
end

"""
Calculate Bernoulli distribution log-likelihood based on precompiled sum dicts

Inputs:
    ns: count dict of current label pair connections
    Ns: count dict of total possible label pair connections
    pr: MxM array of connection probabilities between labels

Outputs:
    ll: log-likelihood function value
"""
function calculate_ll(ns::Dict, Ns::Dict, pr::Array)
    ll = 0
    for (a,b) in keys(ns)
        n = ns[a,b]
        N = Ns[a,b]
        ll += n*log10(pr[a,b]) + (N-n)*log10(1-pr[a,b])
    end
    return ll
end

"""
Calculate log-likelihood after swapping the label of one neuron
    The updates should be O(1) to prevent from total recalculation

Inputs:
    ns: count dict of current label pair connections
    Ns_prepost: count dict of labels classified as pre or post
        indexed by tuple (label id, pre/post id)
    counts: MxN array of count of neighbors per each label
    old_label: current label of neuron to be swapped
    this_prepost: prepost label of neuron that's being swapped

Outputs:
    new_ns: updated ns
    new_Ns: updated Ns
"""
function swap_counts(ns, Ns_prepost, count_adjustments, old_label, this_prepost)
    new_ns = Dict()
    new_Ns = Dict()
    new_label = get_other_class(old_label)
    other_prepost = get_other_class(this_prepost)
    for (a,b) in keys(ns)
        prepost_adjust = 1
        count_adjust = count_adjustments[b]
        if a != new_label
            count_adjust = -count_adjust
            prepost_adjust = -1
        end
        new_ns[a,b] = ns[a,b] + count_adjust
        prepost_changed = Ns_prepost[a,this_prepost] + prepost_adjust
        prepost_same = Ns_prepost[b,other_prepost]
        new_Ns[a,b] = prepost_changed*prepost_same
    end   
    return new_ns, new_Ns
end

"""
Get opposite class from set {1,2}
"""
function get_other_class(class)
    if class == 1
        return 2
    else
        return 1
    end
end

"""
Maximize params

Inputs:
    ns: count dict of current label pair connections
    Ns_prepost: count dict of labels classified as pre or post
        indexed by tuple (label id, pre/post id)
    pr: MxM array of connection probabilities between labels

Outputs:
    updated pr
"""
function maximize_parameters!(ns, Ns, pr)
    for (a,b) in keys(ns)
        pr[a,b] = ns[a,b] / Ns[a,b]
    end
end

"""
Make dummy data to see how well the labels can be recovered
"""
function make_dummy_data(n=20)
    adj = spzeros(n,n)
    # half excitatory, half inhibitory
    labels = ones(Int64, n)
    m = round(Int64, n/4)
    labels[m+1:end] = ones(Int64, length(m+1:n))*2
    prepost = ones(Int64, n)
    prepost[unique(rand(1:n, round(Int64, n/4)))] = 2
    # E,I x E,I
    pr = [0.15 0.12; 0.02 0.02]
    for i in 1:n
        for j in 1:n
            # if (prepost[i] == 1) & (prepost[j] == 2)
            ci, cj = labels[i], labels[j]
            p = pr[ci,cj]
            adj[i,j] = rand() < p
            # end
        end
    end 
    return adj, labels, pr, prepost
end

function run_dummy_test()
    adj, labels, pr, prepost = make_dummy_data(1000)
    pr_guess = rand(2,2)
    labels_guess = rand([1,2], size(adj,1))
    k = size(adj,1)
    labels_changed = true
    n_iter = 10000
    iter = 0
    counts = count_neighbor_labels(adj, labels)
    ns, Ns, Ns_prepost = compile_count_dicts(counts, labels, prepost)
    goal_ll = round(calculate_ll(ns, Ns, pr),2)
    while labels_changed & (iter <= n_iter)
        labels_changed = false
        counts = count_neighbor_labels(adj, labels_guess)
        ns, Ns, Ns_prepost = compile_count_dicts(counts, labels_guess, prepost)
        ll = calculate_ll(ns, Ns, pr_guess)
        for i in 1:k
            c = counts[:,i][:]
            l = labels_guess[i]
            p = prepost[i]
            new_ns, new_Ns = swap_counts(ns, Ns_prepost, c, l, p) 
            new_ll = calculate_ll(new_ns, new_Ns, pr_guess)
            if new_ll - ll > 1e-4
                labels_guess[i] = get_other_class(labels_guess[i])
                labels_changed = true
                maximize_parameters!(new_ns, new_Ns, pr_guess)
                break
            end
        end
        # println("$iter\t$(round(ll,2))\t$(abs(labels-labels_guess))\t$labels_changed")
        println("$iter\t$(round(ll,2))\t$goal_ll\t$(sum(abs(labels-labels_guess)))")
        iter += 1
    end
    println(pr_guess)
    println(pr)
end
