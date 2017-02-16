import Base: +, -, *, /, &, min, max, norm

immutable Vec3
	x::Float64
	y::Float64
	z::Float64
end

typealias Point3 Vec3

(+)(a::Vec3, b::Vec3) = Vec3(a.x + b.x, a.y + b.y, a.z + b.z)
(-)(a::Vec3, b::Vec3) = Vec3(a.x - b.x, a.y - b.y, a.z - b.z)
(*)(p::Vec3, s::Real) = Vec3(p.x*s, p.y*s, p.z*s)
(/)(p::Vec3, s::Real) = Vec3(p.x/s, p.y/s, p.z/s)
(*)(s::Real, p::Vec3) = p*s

norm(p::Vec3) = norm([p.x, p.y, p.z])

immutable BoundingCube
	xmin::Float64
	xmax::Float64
	ymin::Float64
	ymax::Float64
	zmin::Float64
	zmax::Float64
end

function BoundingCube(points::Point3...)
	xmin, xmax, ymin, ymax, zmin, zmax = NaN, NaN, NaN, NaN, NaN, NaN
	for p in points
        xmin = min(xmin, p.x)
        xmax = max(xmax, p.x)
        ymin = min(ymin, p.y)
        ymax = max(ymax, p.y)
        zmin = min(zmin, p.z)
        zmax = max(zmax, p.z)
   end
   return BoundingCube(xmin, xmax, ymin, ymax, zmin, zmax)
end

function BoundingCube(bcubes::BoundingCube...)
    xmin, xmax, ymin, ymax, zmin, zmax = NaN, NaN, NaN, NaN, NaN, NaN
    for bc in bcubes
        xmin = min(xmin, bc.xmin)
        xmax = max(xmax, bc.xmax)
        ymin = min(ymin, bc.ymin)
        ymax = max(ymax, bc.ymax)
        zmin = min(zmin, bc.zmin)
        zmax = max(zmax, bc.zmax)
    end
    return BoundingCube(xmin, xmax, ymin, ymax, zmin, zmax)
end

width(bc::BoundingCube) = bc.xmax - bc.xmin
height(bc::BoundingCube) = bc.ymax - bc.ymin
depth(bc::BoundingCube) = bc.zmax - bc.zmin

volume(bc::BoundingCube) = width(bc)*height(bc)*depth(bc)

xmin(bc::BoundingCube) = bc.xmin
xmax(bc::BoundingCube) = bc.xmax
ymin(bc::BoundingCube) = bc.ymin
ymax(bc::BoundingCube) = bc.ymax
zmin(bc::BoundingCube) = bc.zmin
zmax(bc::BoundingCube) = bc.zmax
min(bc::BoundingCube) = Point3(xmin(bc), ymin(bc), zmin(bc))
max(bc::BoundingCube) = Point3(xmax(bc), ymax(bc), zmax(bc))

center(x) = Point3((xmin(x)+xmax(x))/2, (ymin(x)+ymax(x))/2, 
                                                        (zmin(x)+zmax(x))/2)
xrange(x) = xmin(x), xmax(x)
yrange(x) = ymin(x), ymax(x)
zrange(x) = zmin(x), zmax(x)

"""
Produce bounding box for given list of coordinates
"""
function get_bc(coords)
	return BoundingCube(map(Vec3, ))
end

function (+)(bc1::BoundingCube, bc2::BoundingCube)
    BoundingCube(min(bc1.xmin, bc2.xmin),
                max(bc1.xmax, bc2.xmax),
                min(bc1.ymin, bc2.ymin),
                max(bc1.ymax, bc2.ymax),
                min(bc1.zmin, bc2.zmin),
                max(bc1.zmax, bc2.zmax))
end

function (&)(bc1::BoundingCube, bc2::BoundingCube)
  xmin = max(bc1.xmin, bc2.xmin)
  ymin = max(bc1.ymin, bc2.ymin)
  zmin = max(bc1.zmin, bc2.zmin)
  xmax = min(bc1.xmax, bc2.xmax)
  ymax = min(bc1.ymax, bc2.ymax)
  zmax = min(bc1.zmax, bc2.zmax)
  if xmax < xmin || ymax < ymin || zmax < zmin
    return BoundingCube(NaN, NaN, NaN, NaN, NaN, NaN)
  else
    return BoundingCube(xmin, xmax, ymin, ymax, zmin, zmax)
  end
end

function deform(bc::BoundingCube, dl, dr, dt, db, df, dbk)
    BoundingCube(bc.xmin + dl, bc.xmax + dr, bc.ymin + dt, bc.ymax + db,
                                                bc.zmin + df, bc.zmax + dbk)
end

# shift center by (dx,dy,dz), keeping width, height, & depth fixed
function shift(bc::BoundingCube, dx, dy, dz)
    BoundingCube(bc.xmin + dx, bc.xmax + dx, bc.ymin + dy, bc.ymax + dy,
                                                    bc.zmin + dz, bc.zmax + dz)
end

# scale width, height, & depth, keeping center fixed
function (*)(bc::BoundingCube, s::Real)
    dw = 0.5*(s - 1)*width(bc)
    dh = 0.5*(s - 1)*height(bc)
    dd = 0.5*(s - 1)*depth(bc)
    deform(bc, -dw, dw, -dh, dh, -dd, dd)
end
(*)(s::Real, bc::BoundingCube) = bc*s

isinside(bc::BoundingCube, x, y, z) = (bc.xmin <= x <= bc.xmax) && 
                                        (bc.ymin <= y <= bc.ymax) &&
                                            (bc.zmin <= z <= bc.zmax)
isinside(bc::BoundingCube, p::Point3) = isinside(bc, p.x, p.y, p.z)
