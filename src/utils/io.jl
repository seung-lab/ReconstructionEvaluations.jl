
module io

using HDF5

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


end #module end
