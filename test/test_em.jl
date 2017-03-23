adj = spzeros(6,6)
adj[1,3] = 1
adj[1,5] = 1
adj[2,3] = 1
adj[2,4] = 1
adj[2,5] = 1
adj[2,6] = 1
labels = [1, 2, 1, 2, 1, 2]
labels[2] = labels[4] = labels[6] = 2
counts = count_neighbor_labels(adj, labels)
@test counts[1,1] == 2
@test counts[2,1] == 0
@test counts[1,2] == 2
@test counts[2,2] == 2
@test counts[1,3] == 0
@test counts[2,3] == 0
@test counts[1,4] == 0
@test counts[2,4] == 0

prepost = [1, 1, 2, 2, 2, 2]
ns, Ns, Ns_prepost = compile_count_dicts(counts, labels, prepost)
@test ns[1,1] == 2
@test ns[1,2] == 0
@test ns[2,1] == 2
@test ns[2,2] == 2
@test Ns[1,1] == 2
@test Ns[1,2] == 2
@test Ns[2,1] == 2
@test Ns[2,2] == 2
@test Ns_prepost[1,1] == 1
@test Ns_prepost[1,2] == 2
@test Ns_prepost[2,1] == 1
@test Ns_prepost[2,2] == 2

pr = [0.1 0.2; 0.3 0.4]
ll = calculate_ll(ns, Ns, pr)
@test_approx_eq_eps ll -4.03545 10e-4

i = 1
c = counts[:,i][:]
l = labels[i]
p = prepost[i]
new_ns, new_Ns = swap_counts(ns, Ns_prepost, c, l, p) 
@test new_ns[1,1] == 0
@test new_ns[1,2] == 0
@test new_ns[2,1] == 4
@test new_ns[2,2] == 2
@test new_Ns[1,1] == 0
@test new_Ns[1,2] == 0
@test new_Ns[2,1] == 4
@test new_Ns[2,2] == 4

new_ll = calculate_ll(new_ns, new_Ns, pr)
@test_approx_eq_eps new_ll -3.33109 10e-4

