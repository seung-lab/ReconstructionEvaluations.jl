adj = spzeros(4,4)
adj[1,2] = 1
adj[1,3] = 1
adj[2,4] = 1
adj[4,2] = 1
labels = ones(Int64, size(adj,1))
labels[2] = 2
labels[4] = 2
counts = RE.count_neighbor_labels(adj, labels)
@test counts[1,1] == 1
@test counts[1,2] == 1
@test counts[2,1] == 0
@test counts[2,2] == 1
@test counts[3,1] == 0
@test counts[3,2] == 0
@test counts[4,1] == 0
@test counts[4,2] == 1