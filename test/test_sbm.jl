adj = spzeros(6,6)
adj[1,3] = 1
adj[1,5] = 1
adj[2,3] = 1
adj[2,4] = 1
adj[2,5] = 1
adj[2,6] = 1
labels = [1, 2, 1, 2, 1, 2]
counts = RE.count_neighbor_groups(adj, labels)
@test counts[1,1] == 2
@test counts[2,1] == 0
@test counts[1,2] == 2
@test counts[2,2] == 2
@test counts[1,3] == 0
@test counts[2,3] == 0
@test counts[1,4] == 0
@test counts[2,4] == 0

pairs = [(i,j) for i in [1,2] for j in [1,2]]
ns, ms = RE.compile_count_dicts(counts, labels, pairs)
@test ms[1,1] == 2
@test ms[1,2] == 0
@test ms[2,1] == 2
@test ms[2,2] == 2
@test ns[1] == 3
@test ns[2] == 3

pr = [0.1 0.2; 0.3 0.4]
ll = calculate_ll(ns, ms, pr)
@test_approx_eq_eps ll -7.6713 10e-4

i = 1
count_deltas = counts[:,i][:]
old_label = 1
new_label = 2
new_ns, new_ms = RE.adjust_counts(ns, ms, count_deltas, old_label, new_label) 
@test new_ms[1,1] == 0
@test new_ms[1,2] == 0
@test new_ms[2,1] == 4
@test new_ms[2,2] == 2
@test new_ns[1] == 2
@test new_ns[2] == 4

new_ll = RE.calculate_ll(new_ns, new_ms, pr)
@test_approx_eq_eps new_ll -7.57119 10e-4

new_pr = zeros(2,2)
RE.maximize_parameters!(ns,ms,new_pr)
@test new_pr[1,1] == 2/9
@test new_pr[1,2] == 0
@test new_pr[2,1] == 2/9
@test new_pr[2,2] == 2/9

# test bipartite
labels = [1, 2, 3, 4, 3, 4]
counts = RE.count_neighbor_groups(adj, labels)
@test counts[1,1] == 0
@test counts[2,1] == 0
@test counts[3,1] == 2
@test counts[4,1] == 0
@test counts[1,2] == 0
@test counts[2,2] == 0
@test counts[3,2] == 2
@test counts[4,2] == 2
@test counts[1,3] == 0
@test counts[2,3] == 0
@test counts[3,3] == 0
@test counts[4,3] == 0
@test counts[1,4] == 0
@test counts[2,4] == 0
@test counts[3,4] == 0
@test counts[4,4] == 0
@test counts[1,5] == 0
@test counts[2,5] == 0
@test counts[3,5] == 0
@test counts[4,5] == 0
@test counts[1,6] == 0
@test counts[2,6] == 0
@test counts[3,6] == 0
@test counts[4,6] == 0
pairs = [(i,j) for i in [1,2] for j in [3,4]]
ns, ms = RE.compile_count_dicts(counts, labels, pairs)
@test ms[1,3] == 2
@test ms[1,4] == 0
@test ms[2,3] == 2
@test ms[2,4] == 2
@test ns[1] == 1
@test ns[2] == 1
@test ns[3] == 2
@test ns[4] == 2
@test RE.swap_group(1) == 2
@test RE.swap_group(2) == 1
@test RE.swap_group(3) == 4
@test RE.swap_group(4) == 3