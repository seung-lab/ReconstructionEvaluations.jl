
module Synaptor


"""

    make_cfg( seg_fname, output_prefix, seg_start )

Creates a Synaptor configuration file for the segmentation file passed,
and returns the pathname to it from base_dir. The pathname is currently 
stamped with the date.

"""
function make_cfg( seg_fname, output_prefix, seg_start )

  cfg_fname = "$(output_prefix).cfg"

  open(cfg_fname, "w+") do f

    write(f, "#!/usr/bin/env julia\n" )
    write_field_line(f, "network_output_filename", "nothing" )
    write_field_line(f, "segmentation_filename", "\"$(seg_fname)\"" )
    write_field_line(f, "seg_dset_name", "\"/main\"" )
    write_field_line(f, "output_prefix", "\"$(output_prefix)\"" )
    write_field_line(f, "sem_incore", "false" )
    write_field_line(f, "seg_incore", "true" )
    write_field_line(f, "seg_start", "$seg_start" )
    write_field_line(f, "output_seg_shape", "[2048,2048,256]" )
    write_field_line(f, "seg_chunk_size", "[128,128,16]" )
    write_field_line(f, "scan_start_coord", "[1,1,1]" )
    write_field_line(f, "scan_end_coord", "[2048,2048,256]" )

  end #open

  cfg_fname 
end


"""

    make_gc_cfg( seg_fname, output_prefix )

Makes a 2k cube cfg specific to the golden cube coordinates
"""
function make_gc_cfg( seg_fname, output_prefix )
  make_cfg(seg_fname, output_prefix, [19585,22657,4003])
end


"""

    write_field_line( f, field, val )

Writes a line of the format "field = val" to f
"""
function write_field_line( f, field, val )
  write(f, "$field = $val;\n")
end


"""

    run_cfg_file( cfg_file )

Runs main_ooc.jl on a configuration file
"""
function run_cfg_file( cfg_file )
  this_dir = dirname(@__FILE__)
  main_ooc = joinpath(this_dir,"Synaptor/src/main_ooc.jl")
  run(`julia $main_ooc $cfg_file`)
end


"""
Removes the mapping output file
"""
rm_mapping_file(prefix) = rm("$(output_prefix)_mapping.csv")
"""
Removes the seg output_file
"""
rm_seg_file(prefix) = rm("$(output_prefix)_seg.csv")

end #module end
