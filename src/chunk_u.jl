#!/usr/bin/env julia
__precompile__()


module chunk_u

#=
   Chunking Utilities - chunk_u.jl
=#

export fetch_chunk
export bound_shape, bounds, zip_bounds, intersect_bounds
export chunk_bounds, chunk_bounds2D

export vol_shape

"""

    vol_shape( bounds )

  Returns the overall shape of a subvolume which ranges
  between the two coordinates contained within the Pair bounds.
"""
function bound_shape( bounds::Pair )
  bounds.second - bounds.first + 1
end


@inline function zip_bounds( bounds::Pair )

  #need Any for possible Colon()s
  bz = Vector{Any}(length(bounds.first))

  for i in eachindex(bounds.first)
    bz[i] = bounds.first[i]:bounds.second[i]
  end

  bz
end


"""

    fetch_chunk( d, bounds::Pair, offset )

  Generalized function to fetch a 3d chunk
  from within an Nd Array, H5Dataset, etc.
"""
function fetch_chunk( d, bounds::Pair, offset=[0,0,0] )

  shifted = (bounds.first  + offset) => (bounds.second + offset);
  zipped = zip_bounds(shifted)

  while length(zipped) < length(size(d)) push!(zipped,Colon()) end

  d[zipped...]
end


"""
    chunk_bounds( vol_size, chunk_size )

  Computes the index bounds for splitting a volume
  into chunks of a maximum size. If the dimensions
  don't match to allow for perfect splitting, smaller
  are included at the end of each dimension. The offset coordinate
  is added to each resulting bound.
"""
function chunk_bounds( vol_size, chunk_size, offset=[0,0,0] )

  x_bounds = bounds1D( vol_size[1], chunk_size[1] )
  y_bounds = bounds1D( vol_size[2], chunk_size[2] )
  z_bounds = bounds1D( vol_size[3], chunk_size[3] )

  num_bounds = prod(
    (length(x_bounds), length(y_bounds), length(z_bounds))
    )
  bounds = Vector{Pair{Vector{Int},Vector{Int}}
                 }(num_bounds)
  i=0;

  for z in z_bounds
    for y in y_bounds
      for x in x_bounds
        i+=1;
        bounds[i] = [x.first,  y.first,  z.first] + offset =>
                    [x.second, y.second, z.second] + offset
      end
    end
  end

  bounds
end


"""

    chunk_bounds2D( vol_size, chunk_size, offset=[0,0] )

  Computes the index bounds for splitting a 2D image
  into chunks of a maximum size. If the dimensions
  don't match to allow for perfect splitting, smaller chunks
  are included at the end of each dimension. The offset coordinate
  is added to each resulting bound.
"""
function chunk_bounds2D( vol_size, chunk_size, offset=[0,0] )

  x_bounds = bounds1D( vol_size[1], chunk_size[1] )
  y_bounds = bounds1D( vol_size[2], chunk_size[2] )

  num_bounds = prod(
    (length(x_bounds), length(y_bounds))
  )

  bounds = Vector{Pair{Vector{Int},Vector{Int}}
                }(num_bounds)
  i=0

  for y in y_bounds
    for x in x_bounds
      i+=1;
      bounds[i] = [x.first,  y.first] + offset =>
                  [x.second, y.second] + offset
    end
  end

  bounds
end

"""

    bounds1D( full_width, step_size )

  Returns the 1D index bounds for splitting an interval
  of a given width into increments of a given step size.
  Includes smaller increments at the end if the interval
  isn't evenly divided
"""
function bounds1D( full_width, step_size )

  @assert step_size > 0
  @assert full_width > 0

  start = 1
  ending = step_size

  num_bounds = convert(Int,ceil(full_width / step_size));
  bounds = Vector{Pair{Int,Int}}( num_bounds )

  i=1;
  while ending < full_width
    bounds[i] = start => ending

    i += 1;
    start  += step_size
    ending += step_size
  end

  #last window for remainder
  bounds[end] = start => full_width

  bounds
end

"""
Tests whether a voxel coordinate is within 3d bounds
"""
function in_bounds( voxel, bounds )

  #BROADCASTING IS THE DEVIL
  # ( all(voxel .>= bounds.first) &&
  #   all(voxel .<= bounds.second)  )

  b_beg, b_end = bounds

  ( voxel[1] >= b_beg[1] &&
    voxel[2] >= b_beg[2] &&
    voxel[3] >= b_beg[3] &&

    voxel[1] <= b_end[1] &&
    voxel[2] <= b_end[2] &&
    voxel[3] <= b_end[3] )
end

function in_bounds2D( voxel, bounds )

  b_beg, b_end = bounds

  ( voxel[1] >= b_beg[1] &&
    voxel[2] >= b_beg[2] &&

    voxel[1] <= b_end[1] &&
    voxel[2] <= b_end[2] )
end


"""

    bounds( d, offset=[0,0,0] )

  Extracts the index bounds for general purpose objects
  which have size and a given offset
"""
function bounds( d, offset=[0,0,0] )
  offset + 1 => collect(size(d)[1:3]) + offset
end


"""

    intersect_bounds( bounds1, bounds2, bounds2_offset )

  Takes two index bounds defined by Pairs and returns their
  intersection. Performs no checking for validity of the result
  (i.e. the result can specify bounds with 0 or negative volume).
"""
function intersect_bounds( bounds1, bounds2, bounds2_offset )
  b1_beg, b1_end = bounds1
  b2_beg = bounds2.first  + bounds2_offset
  b2_end = bounds2.second + bounds2_offset

  max( b1_beg, b2_beg ) => min( b1_end, b2_end )
end


end#module
