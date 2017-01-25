function test_edges_to_syn_dicts()
	tbl = Array{Any,2}(1,3);
	tbl[1,:] = [1, [1,2], [1,1,1]];
	pre, post = edges_to_syn_dicts(tbl)
	@test length(pre) == 1
	@test length(post) == 1
	@test pre[1] == 1
	@test post[1] == 2
end

function test_map_synapses()
	tbl_A = Array{Any,2}(2,3);
	tbl_B = Array{Any,2}(2,3);
	tbl_A[1,:] = [1, [1,2], [1,1,1]]
	tbl_A[2,:] = [5, [2,3], [1,2,1]]
	tbl_B[1,:] = [10, [20,21], [1,1,1]]
	tbl_B[2,:] = [1, [1,2], [1,1,5]]	
	A_to_B = map_synapses(tbl_A, tbl_B)
	@test size(A_to_B) == (3,2)
	@test A_to_B[1,1] == 1
	@test A_to_B[1,2] == 10
	@test A_to_B[2,1] == 5
	@test A_to_B[2,2] == 0
	@test A_to_B[3,1] == 0
	@test A_to_B[3,2] == 1
end

function test_get_indexed_seg_IDs()
	tbl = Array{Any,2}(2,3);
	tbl[1,:] = [1, [1,2], [1,1,1]]
	tbl[2,:] = [5, [2,5], [1,2,1]]	
	seg_indices = get_indexed_seg_IDs(tbl)
	@test length(seg_indices) == 3
	@test seg_indices[1] == 1
	@test seg_indices[2] == 2
	@test seg_indices[5] == 3
	@test !haskey(seg_indices, 3)
end

function test_build_count_table()
	tbl_A = Array{Any,2}(2,3);
	tbl_B = Array{Any,2}(2,3);
	tbl_A[1,:] = [1, [1,2], [1,1,1]]
	tbl_A[2,:] = [5, [2,3], [1,2,1]]
	tbl_B[1,:] = [10, [20,21], [1,1,1]]
	tbl_B[2,:] = [1, [1,2], [1,1,5]]
	count_table = build_count_table(tbl_A, tbl_B)
	@test size(count_table) == (3+1,4+1)
	@test count_table[1,1] == 0
	@test count_table[1,2] == 1
	@test count_table[1,3] == 1
	@test count_table[1,4] == 0
	@test count_table[1,5] == 0	
	@test count_table[2,1] == 0
	@test count_table[2,2] == 0
	@test count_table[2,3] == 0
	@test count_table[2,4] == 1
	@test count_table[2,5] == 0
	@test count_table[3,1] == 1
	@test count_table[3,2] == 0
	@test count_table[3,3] == 0
	@test count_table[3,4] == 0
	@test count_table[3,5] == 1
	@test count_table[4,1] == 1
	@test count_table[4,2] == 0
	@test count_table[4,3] == 0
	@test count_table[4,4] == 0
	@test count_table[4,5] == 0
end

function create_dummy_count_table()
	tbl_A = Array{Any,2}(3,3);
	tbl_B = Array{Any,2}(3,3);
	tbl_A[1,:] = [1, [1,2], [1,1,1]]
	tbl_A[2,:] = [5, [2,3], [1,2,1]]
	tbl_A[3,:] = [7, [1,3], [1,3,3]]
	tbl_B[1,:] = [10, [20,21], [1,1,1]]
	tbl_B[2,:] = [1, [1,2], [1,1,5]]
	tbl_B[3,:] = [4, [20,2], [1,3,3]]
	return build_count_table(tbl_A, tbl_B)
end

function test_merge_columns()
	count_table = create_dummy_count_table()
	@test_throws AssertionError merge_columns(count_table, 1, 2)
	@test_throws AssertionError merge_columns(count_table, 6, 2)
	@test_throws AssertionError merge_columns(count_table, 2, 1)
	@test_throws AssertionError merge_columns(count_table, 2, 6)
	count_table = merge_columns(count_table, 3, 5)
	@test size(count_table) == (4,4)
	@test count_table[1,3] == 1
	@test count_table[2,3] == 0
	@test count_table[3,3] == 1
	@test count_table[4,3] == 1
end

function test_split_column()
	count_table = create_dummy_count_table()
	@test_throws AssertionError split_column(count_table, 1)
	@test_throws AssertionError split_column(count_table, 6)
	count_table = split_column(count_table, 4)
	@test size(count_table) == (4,6)
	@test count_table[1,4] == 0
	@test count_table[2,4] == 1
	@test count_table[3,4] == 0
	@test count_table[4,4] == 0
	@test count_table[1,5] == 0
	@test count_table[2,5] == 1
	@test count_table[3,5] == 0
	@test count_table[4,5] == 0
	@test count_table[2,1] == 0
end

function test_remove_synapse()
	count_table = create_dummy_count_table()
	@test_throws AssertionError remove_synapse(count_table, (1,2), (2,3))
	@test_throws AssertionError remove_synapse(count_table, (6,2), (2,3))
	@test_throws AssertionError remove_synapse(count_table, (2,1), (2,3))
	@test_throws AssertionError remove_synapse(count_table, (2,6), (2,3))
	count_table = remove_synapse(count_table, (2,4), (3,5))
	@test size(count_table) == (4,5)
	@test count_table[1,1] == 0
	@test count_table[2,1] == 1
	@test count_table[3,1] == 2
	@test count_table[4,1] == 1
	@test count_table[1,4] == 0
	@test count_table[2,4] == 1
	@test count_table[3,4] == 0
	@test count_table[4,4] == 0
	@test count_table[1,5] == 0
	@test count_table[2,5] == 0
	@test count_table[3,5] == 0
	@test count_table[4,5] == 0
end

function test_add_synapse()
	count_table = create_dummy_count_table()
	@test_throws AssertionError add_synapse(count_table, (1,2))
	@test_throws AssertionError add_synapse(count_table, (6,2))
	@test_throws AssertionError add_synapse(count_table, (2,1))
	@test_throws AssertionError add_synapse(count_table, (2,6))
	count_table = add_synapse(count_table, (2,4))
	@test size(count_table) == (4,5)
	@test count_table[1,1] == 0
	@test count_table[1,2] == 2
	@test count_table[1,3] == 1
	@test count_table[1,4] == 1
	@test count_table[1,5] == 0
end


test_edges_to_syn_dicts()
test_map_synapses()
test_get_indexed_seg_IDs()
test_build_count_table()
test_merge_columns()
test_split_column()
test_remove_synapse()
test_add_synapse()