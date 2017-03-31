"""
Create table of neighbor group tallys (how many neighbors are in each group?)

Inputs:
    adj: sparse adjacency matrix (NxN)
    groups: integer list of each node's group (Nx1)

Outputs:
    counts: MxN array of count of neighbors per each group
"""
function count_neighbor_groups(adj, groups)
    assert(size(adj,1) == length(groups))
    n = size(adj,1)
    counts = zeros(Int64,4,n)
    rows = rowvals(adj)
    for i in 1:n
        for j in nzrange(adj, i)
            row = rows[j]
            counts[groups[i],row] += 1 
        end
    end
    return counts
end

"""
Count total degree (stubs) of each group

Inputs:
    ms: dict of edge count between groups

Outputs:
    ks: dict of total degree (stub) count for group
"""
function compile_degree_dict(ms)
    ks = Dict()
    for (a,b) in keys(ms)
        if !(a in keys(ks))
            ks[a] = 0
        end
        ks[a] += ms[a,b]
        if !(b in keys(ks))
            ks[b] = 0
        end
        ks[b] += ms[a,b]
    end
    for i in keys(ks)
        ks[i] = round(Int64, ks[i]/2)
    end
    return ks
end

"""
Compile dicts that count nodes within groups & edges between groups

Inputs:
    counts: MxN array of count of neighbors per each group 
        (see count_neighbor_groups)
    groups: Nx1 group assignment of each node
    pairs: list of tuples, each tuple specifying a pair of groups
        Dicts will only be compiled for the group pairs provided. This pairs 
        list will ensure that only these provided pairs are used in later 
        computations.

Outputs:
    ms: dict of edge count between groups
    ns: dict of node count within groups
    ks: dict of total degree (stub) count for group
"""
function compile_count_dicts(counts, groups, pairs)
    ns = Dict()
    ms = Dict()
    for (a,b) in pairs
        ms[a,b] = sum(counts[b, groups.==a])
        ns[a] = sum(groups.==a)
        ns[b] = sum(groups.==b)
    end
    return ns, ms
end

"""
Calculate log-likelihood after swapping the group of one node
    The updates should be O(1) to prevent from total recalculation

Inputs:
    ns: count dict of current label pair connections
    count_deltas: Mx1 array of swapped node neighbor group counts
    old_group: old group of swapped node
    new_group: new group of swapped node

Outputs:
    new_ns: updated ns
    new_ms: updated ms
"""
function adjust_counts(ns, ms, count_deltas, old_group, new_group)
    new_ns = copy(ns)
    new_ns[old_group] = ns[old_group] - 1
    new_ns[new_group] = ns[new_group] + 1
    new_ms = Dict()
    for (a,b) in keys(ms)
        count_adjust = count_deltas[b]
        if a == new_group
            new_ms[a,b] = ms[a,b] + count_deltas[b]
        elseif a == old_group
            new_ms[a,b] = ms[a,b] - count_deltas[b]
        end
    end
    return new_ns, new_ms
end

"""
Calculate Bernoulli distribution log-likelihood based on count dicts

Inputs:
    ns: dict of node count within groups OR stub count for group (ks)
    ms: dict of edge count between groups

Outputs:
    ll: log-likelihood function value
"""
function calculate_ll(ns::Dict, ms::Dict, method="bernoulli")
    ll = 0
    for (a,b) in keys(ms)
        na = ns[a]
        nb = ns[b]
        m = ms[a,b]
        if na*nb != 0
            if method == "bernoulli"
                ll += m*log10(m/(na*nb)) + (na*nb-m)*log10(1-m/(na*nb))
            elseif method == "poisson"
                ll += m*log10(m/(na*nb))
            end
        end
    end
    return ll
end

"""
Maximize params

Inputs:
    ms: dict of edge count between groups
    ns: dict of node count within groups
    pr: MxM array of connection probabilities between groups

Outputs:
    updated pr
"""
function maximize_parameters!(ns, ms, pr)
    for (a,b) in keys(ms)
        pr[a,b] = ms[a,b] / (ns[a]*ns[b])
    end
end

"""
Get opposite group
"""
function swap_group(old_group)
    if old_group == 1
        return 2
    elseif old_group == 2
        return 1
    elseif old_group == 3
        return 4
    elseif old_group == 4
        return 3
    end
end

"""
Make dummy data to see how well the groups can be recovered
"""
function make_dummy_data(n=40)
    adj = spzeros(n,n)
    # 3/4 pre, 1/4 post; 1/2 excitatory, 1/2 inhibitory
    groups = ones(Int64, n)
    m = round(Int64, 3*n/8)
    groups[1:end-m] = ones(Int64, n-m)*2
    m = round(Int64, 6*n/8)
    groups[1:end-m] = ones(Int64, n-m)*3
    m = round(Int64, 7*n/8)
    groups[1:end-m] = ones(Int64, n-m)*4
    pairs = [(i,j) for i in [1,2] for j in [3,4]]
    # E_pre,I_pre,E_post,I_post x E_pre,I_pre,E_post,I_post
    pr = [0 0 0.15 0.12;
          0 0 0.02 0.02;
          0 0 0 0;
          0 0 0 0]
    for i in 1:n
        for j in 1:n
            ci, cj = groups[i], groups[j]
            p = pr[ci,cj]
            adj[i,j] = rand() < p
        end
    end 
    return adj, groups, pr, pairs
end

function run_dummy_test()
    adj, groups, pr, pairs = make_dummy_data(1000)
    method = "poisson"
    groups_guess = copy(groups[r])
    groups_guess[groups_guess .<= 2] = rand([1,2], sum(groups .<= 2))
    groups_guess[groups_guess .>= 3] = rand([3,4], sum(groups .>= 3))
    k = size(adj,1)
    groups_changed = true
    n_iter = 3000
    iter = 0
    counts = count_neighbor_groups(radj, groups[r])
    ns, ms = compile_count_dicts(counts, groups[r], pairs)
    goal_ll = calculate_ll(ns, ms, method)
    results = []
    while groups_changed & (iter <= n_iter)
        groups_changed = false
        counts = count_neighbor_groups(radj, groups_guess)
        ns, ms = compile_count_dicts(counts, groups_guess, pairs)
        ll = calculate_ll(ns, ms, method)
        for i in randperm(k)
            count_deltas = counts[:,i][:]
            old_group = groups_guess[i]
            new_group = swap_group(old_group)
            new_ns, new_ms = adjust_counts(ns, ms, count_deltas, old_group, new_group)
            new_ll = calculate_ll(new_ns, new_ms, method)
            if new_ll - ll > 1e-4
                groups_guess[i] = new_group
                groups_changed = true
                break
            end
        end
        push!(results, [iter, ll, goal_ll, sum(abs(groups[r]-groups_guess))])
        iter += 1
        print("\r $iter")
    end
end
