"""
Load segment size list
"""
function load_seg_list(fn)
    return readdlm(fn, ';', Int64)
end

function load_semmap(fname)
    table = readdlm(fname, ';', Int)
    Dict( table[i,1] => table[i,2] for i in 1:size(table,1) )
end

"""
Load Synaptor edge csv & parse columns appropriately
"""
function load_edges(fn)
    tbl = readdlm(fn, ';')[:,1:4]
    tbl[:,2] = [map(parse, split(tbl[i,2][2:end-1],",")) for i in 1:size(tbl,1)]
    tbl[:,3] = [map(parse, split(tbl[i,3][2:end-1],",")) for i in 1:size(tbl,1)]
    return tbl
end

"""
Load Omni working/valid/uncertain
"""
function load_valid_list(fn)
	return readdlm(fn, ',', Int64)
end

function read_h5( fname, read_whole_dset=true, h5_dset_name="/main" )

  if read_whole_dset
    d = h5read( fname, h5_dset_name );
  else
    f = h5open( fname );
    d = f[h5_dset_name];
  end

  d
end

function write_map_file( output_fname, dicts... )

  open(output_fname, "w+") do f
    if length(dicts) > 0
    for k in keys(dicts[1])

      vals = ["$(d[k]);" for d in dicts ];
      write(f, "$k;$(vals...)\n")

    end #for
    end #if
  end#open

end

"""
Load sparse matrix from file with format i, j, v
"""
function read_sparse(fn)
    d = readdlm(fn)
    n = Int64(maximum(d[:,1]))
    m = Int64(maximum(d[:,2]))
    S = spzeros(n,m)
    for i in 1:size(d,1)
        S[Int64(d[i,1]), Int64(d[i,2])] = d[i,3]
    end
    return S
end

"""
Write sparse matrix to file with format i, j, v
"""
function write_sparse(fn, arr)
    r = []
    c = []
    v = []
    rows = rowvals(arr)
    vals = nonzeros(arr)
    n = size(arr,1)
    for j in 1:n
        for i in nzrange(arr, j)
            push!(r, rows[i])
            push!(c, j)
            push!(v, vals[i])
        end
    end
    if length(nzrange(arr, n)) == 0
        push!(r, n)
        push!(c, n)
        push!(v, 0)
    end
    if !(n in rows)
        push!(r, n)
        push!(c, n)
        push!(v, 0)
    end

    writedlm(fn, hcat(r,c,v))
end