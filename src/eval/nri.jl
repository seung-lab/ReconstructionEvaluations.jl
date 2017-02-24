"""
Run the T&E team MATLAB function on the count table

Input:
    count_table: NxM array composed by build_count_table

Output:
    Volume-wide NRI
    Array of segment specific NRIs (Mx1)
"""
function compute_nri(count_table)
    check_MATLAB()
    put_variable(s1, :x, count_table)
    # return mxcall(:nri, 1, count_table)
    eval_string(s1, "[n, nN, roc] = nri(double(x));")
    return jscalar(get_mvariable(s1, :n)), jvector(get_mvariable(s1, :nN)), 
                                                  jdict(get_mvariable(s1, :roc))
end

"""
Overload compute_nri for edge table inputs

Input:
  table1: reconstruction edge list
  table2: ground truth edge list

Output:
    NRI outputs
    count table: sparse matrix build according to function build_count_table
    list of row segment ids sorted by index (matches output of per neuron NRI)
    list of col segment ids sorted by index
"""
function compute_nri( table1::Array, table2::Array )
  count_table, A_to_inds, B_to_inds = build_count_table(table1, table2)
  return compute_nri(count_table), count_table,
              sort_keys_by_val(A_to_inds), sort_keys_by_val(B_to_inds)
end

"""
Overload compute_nri for edge table filename inputs

Input:
  fname1: reconstruction edge list filename
  fname2: ground truth edge list filename
  
Output:
  see compute_nri above
"""
function compute_nri( fname1::AbstractString, fname2::AbstractString )
  table1, table2 = load_edges(fname1), load_edges(fname2)
  return compute_nri(table1, table2)
end

"""
Simulate n mergers on the count table
"""
function merge_sensitivity(count_table, n)
    f1 = []
    c = count_table
    for k=1:n
        sz = size(c)
        i = rand(2:sz[2])
        j = rand(2:sz[2])
        # println((sz, (i,j)))
        c = merge_columns(c, i, j);
        push!(f1, compute_nri(c))
   end
   return f1, c
end

"""
Simulate n splits on the count table
"""
function split_sensitivity(count_table, n)
    f1 = []
    c = count_table
    for k=1:n
        # always pick a neuron with more than 2 synapses to split
        gt_one = collect(2:size(c,2))[sum(c[:,2:end],1) .> 1]
        j = rand(gt_one)
        c = split_column(c, j);
        push!(f1, compute_nri(c))
        # println(f1[end])
   end
   return f1, c
end