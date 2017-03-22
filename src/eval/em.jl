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
    labels = unique(labels)
    counts = zeros(Int64,length(labels),n)
    rows = rowvals(adj)
    # vals = nonzeros(adj)
    for i in 1:n
        for j in nzrange(adj, i)
            row = rows[j]
            # val = vals[j]
            neighbor_label = labels[row]
            counts[j,neighbor_label] += 1 
        end
    end
    return counts
end

"""
Calculate log-likelihood function

Inputs:
    counts: MxN array of count of neighbors per each label 
        (see count_neighbor_labels)
    labels: Nx1 label assignment of each neuron
    pr: MxM array of connection probabilities between labels

Outputs:
    ll: log-likelihood function value
    ns: count dict of current label pair connections
    Ns: count dict of total possible label pair connections
"""
function calculate_ll(counts::Array, labels::Array, pr::Array)
    pairs = []
    for i in 1:size(pr,1)
        for j in 1:size(pr,1)
            push!(pairs, (i,j))
        end
    end
    ns = Dict()
    Ns = Dict()
    for (a,b) in pairs
        n = sum(counts[a, labels.==b])
        N = sum(labels.==a)*sum(labels.==b)
        ns[a,b] = n
        Ns[a,b] = N
    end
    ll = calculate_ll(ns, Ns, pr)
    return ll, ns, Ns
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
    for (a,b) in pairs
        ll += n*log10(pr[a,b]) + (N-n)*log10(1-pr[a,b])
    end
    return ll
end

"""
Calculate log-likelihood after switching label of one neuron
    The updates should be O(1) to prevent from total recalculation

Inputs:
    ll: base log-likelihood
    ns: count dict of current label pair connections
    Ns: count dict of total possible label pair connections
    pr: MxM array of connection probabilities between labels
    counts: MxN array of count of neighbors per each label
    labels: integer list of each neuron's label (Nx1)
    i: index of neuron whose label will be switched

Outputs:
    ll: log-likelihood after neuron i's label has been switched
"""
function calculate_switch_label_ll(ll, ns, Ns, pr, counts, labels, i)
    old_label = labels[i]
    new_label = get_switched_label(labels, i)
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

    return calculate_ll(ns, Ns, pr)
end

"""
Switch label of neuron i
"""
function get_switched_label(labels, i)
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
    # E,I x E,I
    pr = [0.6 0.2; 0.4 0.3]
    for i in 1:n
        for j in 1:n
            ci, cj = labels[i], labels[j]
            p = pr[ci,cj]
            adj[i,j] = rand() < p
        end
    end 
    return adj, labels, pr
end

function run_dummy_test()
    adj, labels, pr = make_dummy_data()
    k = size(adj,1)
    labels_changed = true
    n_iter = 5
    iter = 0
    while label_changed | iter >= n_iter 
        labels_changed = false
        counts = count_neighbor_labels(adj, labels)
        ll, ns, Ns = calculate_ll(counts, labels, pr)
        for i in 1:k
            switch_ll = calculate_switch_label_ll(ll, ns, Ns, pr, counts, labels, i)
            if switch_ll > ll
                labels[i] = get_switched_label(labels, i)
                labels_changed = true
            end
        end
        iter += 1
    end
end
