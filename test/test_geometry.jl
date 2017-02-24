## Point3-vector identity (typealias)
@test Point3(2, 1, 3) == Vec3(2, 1, 3)

## Vector operators
@test Vec3(1, 2, 3) + Vec3(3, 4, 0) == Vec3(4, 6, 3)
@test Vec3(1, 2, 3) - Vec3(3, 4, 0) == Vec3(-2, -2, 3)
@test Vec3(1, 2, 3) * 1 == Vec3(1, 2, 3) # identity
@test Vec3(1, 2, 3) * 0 == Vec3(0, 0, 0) # null
@test Vec3(1, 2, 3) * 2 == Vec3(2, 4, 6) # scalar multiplication
@test Vec3(1, 2, 3) / 2 == Vec3(0.5, 1, 1.5)

## Euclidean norm/magnitude: norm()
@test norm(Vec3(1, 2, 0)) == sqrt(5)
@test norm(Vec3(0, 0, 0)) == 0

## Bounding boxes: BoundingCube
BCT_point_1 = Vec3(1, 1, 1)
BCT_point_2 = Vec3(2, 3, 2)
BCT_point_3 = Vec3(4, 5, 3)
BCT = BoundingCube(BCT_point_1, BCT_point_2, BCT_point_3)

### BoundingCube attributes
@test BCT == BoundingCube(1, 4, 1, 5, 1, 3)
@test height(BCT) == 4
@test width(BCT) == 3
@test depth(BCT) == 2
@test xmin(BCT) == 1
@test xmax(BCT) == 4
@test center(BCT) == Vec3(2.5, 3, 2)
@test xrange(BCT) == (1, 4)
@test yrange(BCT) == (1, 5)
@test zrange(BCT) == (1, 3)

### BoundingCube operations
BCT_1 = BoundingCube(2, 3, 4, 5, 6, 7)
BCT_2 = BoundingCube(6, 7, 8, 9, 10, 11)

#### BoundingCube (+)
@test BCT_1 + BCT_2 == BoundingCube(2, 7, 4, 9, 6, 11)

#### BoundingCube (&)
@test BCT_1 & BCT_2 == BoundingCube(NaN, NaN, NaN, NaN, NaN, NaN)

BCT_3 = BoundingCube(1, 5, 1, 5, 1, 5)
BCT_4 = BoundingCube(2, 8, 2, 8, 2, 8)

@test BCT_3 & BCT_4 == BoundingCube(2, 5, 2, 5, 2, 5)

#### deform()
@test deform(BCT_1, -1, 2, -3, 4, -5, 6) == BoundingCube(1, 5, 1, 9, 1, 13)

#### shift()
@test shift(BCT_1, -1, 2, -3) == BoundingCube(1, 2, 6, 7, 3, 4)

#### scale()
@test BCT_1 * 3 == BoundingCube(1, 4, 3, 6, 5, 8)

#### isinside()
@test is_inside(BCT_1, Point3(2.5, 4.5, 6.5))
@test is_inside(BCT_1, Point3(2, 4, 6))
@test is_inside(BCT_1, Point3(1, 3, 5)) == false