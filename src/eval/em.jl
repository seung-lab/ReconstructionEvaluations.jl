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
    counts = zeros(Int64,length(unique(labels)),n)
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
"""
function compile_count_dicts(counts::Array, labels::Array, pre_post::Array)
    pairs = []
    for i in unique(labels)
        for j in unique(labels)
            push!(pairs, (i,j))
        end
    end
    ns = Dict()
    Ns = Dict()
    for (a,b) in pairs
        n = sum(counts[b, labels.==a])
        N = sum((labels.==a)&(pre_post.==1))*sum((labels.==b)&(pre_post.==2))
        ns[a,b] = n
        Ns[a,b] = N
    end
    return ns, Ns
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
    Ns: count dict of total possible label pair connections
    counts: MxN array of count of neighbors per each label
    labels: integer list of each neuron's label (Nx1)
    pre_post: Nx1 int classification or pre (1) or post (2)
    i: index of neuron whose label will be swapped

Outputs:
    updated ns
    updated Ns
"""
function adjust_dicts_swap(ns, Ns, counts, labels, pre_post, i)
    old_label = labels[i]
    new_label = get_swapped_label(labels, i)
    count_adjustments = counts[:,i][:]
    for (a,b) in keys(ns)
        adjust = count_adjustments[b]
        if a != new_label
            adjust = -adjust
        end
        ns[a,b] = adjust
    end   

    old_count = Ns[old_label, old_label]
    new_count = Ns[new_label, new_label]
    spl_count = Ns[old_label, new_label]
    Ns[old_label, old_label] = (round(Int64, sqrt(old_count)) - 1)^2
    Ns[new_label, new_label] = (round(Int64, sqrt(new_count)) + 1)^2
    Ns[old_label, new_label] = (round(Int64, spl_count/old_count) + 1) *
                                        (round(Int64, sqrt(old_count)) - 1)
    Ns[new_label, old_label] = Ns[old_label, new_label]

    return ns, Ns
end

"""
Swap label of neuron i
"""
function get_swapped_label(labels, i)
    old_label = labels[i]
    return setdiff(unique(labels), [old_label])[1]
end

"""
Make dummy data to see how well the labels can be recovered
"""
function make_dummy_data(n=20)
    adj = spzeros(n,n)
    # half excitatory, half inhibitory
    labels = ones(Int64, n)
    m = round(Int64, n/2)
    labels[m+1:end] = ones(Int64, length(m+1:n))*2
    pre_post = ones(Int64, n)
    pre_post[unique(rand(1:n, round(Int64, n/4)))] = 2
    # E,I x E,I
    pr = [0.6 0.2; 0.4 0.3]
    for i in 1:n
        for j in 1:n
            if pre_post[i] == 1 & pre_post[j] == 2
                ci, cj = labels[i], labels[j]
                p = pr[ci,cj]
                adj[i,j] = rand() < p
            end
        end
    end 
    return adj, labels, pr, pre_post
end

function run_dummy_test()
    adj, labels, pr, pre_post = make_dummy_data()
    k = size(adj,1)
    labels_changed = true
    n_iter = 5
    iter = 0
    while label_changed | iter >= n_iter 
        labels_changed = false
        counts = count_neighbor_labels(adj, labels)
        ns, Ns = compile_count_dicts(counts, labels, pre_post)
        ll = calculate_ll(ns, Ns, pr)
        for i in 1:k
            new_ns, new_Ns = swap_label_ll(ns, Ns, pre_post, counts, labels, i)
            new_ll = calculate_ll(new_ns, new_Ns, pr)
            if new_ll > ll
                labels[i] = get_swapped_label(labels, i)
                labels_changed = true
            end
        end
        iter += 1
    end
end
