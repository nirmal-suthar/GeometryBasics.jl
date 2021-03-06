using Test, Random, StructArrays, Tables, StaticArrays
using GeometryBasics
using LinearAlgebra

@testset "GeometryBasics" begin

@testset "embedding metadata" begin
    @testset "Meshes" begin

        @testset "per vertex attributes" begin
            points = rand(Point{3, Float64}, 8)
            tfaces = TetrahedronFace{Int}[(1, 2, 3, 4), (5, 6, 7, 8)]
            normals = rand(SVector{3, Float64}, 8)
            stress = LinRange(0, 1, 8)
            mesh = Mesh(meta(points, normals = normals, stress = stress), tfaces)

            @test hasproperty(coordinates(mesh), :stress)
            @test hasproperty(coordinates(mesh), :normals)
            @test coordinates(mesh).stress === stress
            @test coordinates(mesh).normals === normals
            @test coordinates(mesh).normals === normals
            @test GeometryBasics.faces(mesh) === tfaces
            @test propertynames(coordinates(mesh)) == (:position, :normals, :stress)

        end

        @testset "per face attributes" begin

            # Construct a cube out of Quads
            points = Point{3, Float64}[
                (0.0, 0.0, 0.0), (2.0, 0.0, 0.0),
                (2.0, 2.0, 0.0), (0.0, 2.0, 0.0),
                (0.0, 0.0, 12.0), (2.0, 0.0, 12.0),
                (2.0, 2.0, 12.0), (0.0, 2.0, 12.0)
            ]

            facets = QuadFace{Cint}[
                1:4,
                5:8,
                [1,5,6,2],
                [2,6,7,3],
                [3, 7, 8, 4],
                [4, 8, 5, 1]
            ]

            markers = Cint[-1, -2, 0, 0, 0, 0]
            # attach some additional information to our faces!
            mesh = Mesh(points, meta(facets, markers = markers))
            @test hasproperty(GeometryBasics.faces(mesh), :markers)
            # test with === to assert we're not doing any copies
            @test GeometryBasics.faces(mesh).markers === markers
            @test coordinates(mesh) === points
            @test metafree(GeometryBasics.faces(mesh)) === facets

        end

    end
    @testset "polygon with metadata" begin
        polys = [Polygon(rand(Point{2, Float32}, 20)) for i in 1:10]
        pnames = [randstring(4) for i in 1:10]
        numbers = LinRange(0.0, 1.0, 10)
        bin = rand(Bool, 10)
        # create just an array
        plain = meta(polys, name = pnames, value = numbers, category = bin)
        # create a MultiPolygon with the right type & meta information!
        multipoly = MultiPolygon(polys; name = pnames, value = numbers, category = bin)
        for x in (plain, multipoly)
            for (mp, p, n, num, b) in zip(x, polys, pnames, numbers, bin)
                @test mp.polygon == p
                @test mp.name == n
                @test mp.value == num
                @test mp.category == b
            end

            filtered = filter(i -> i.value < 0.7, x)
            @test length(filtered) == 7
        end
    end

    @testset "point with metadata" begin
        p = Point(1.1, 2.2)
        @test p isa AbstractVector{Float64}
        pm = GeometryBasics.PointMeta(1.1, 2.2; a=1, b=2)
        @test meta(pm) === (a=1, b=2)
        @test metafree(pm) === p
        @test propertynames(pm) == (:position, :a, :b)
    end
end

@testset "view" begin
    @testset "TupleView" begin
        x = [1, 2, 3, 4, 5, 6]
        y = TupleView{2, 1}(x)
        @test y == [(1, 2), (2, 3), (3, 4), (4, 5), (5, 6)]

        y = TupleView{2}(x)
        @test y == [(1, 2), (3, 4), (5, 6)]

        y = TupleView{2, 3}(x)
        @test y == [(1, 2), (4, 5)]

        y = TupleView{3, 1}(x)
        @test y == [(1, 2, 3), (2, 3, 4), (3, 4, 5), (4, 5, 6)]

        y = TupleView{2, 1}(x, connect = true)
        @test y == [(1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 1)]

    end

    @testset "connected views" begin
        numbers = [1, 2, 3, 4, 5, 6]
        x = connect(numbers, Point{2})

        @test x == Point[(1, 2), (3, 4), (5, 6)]

        line = connect(x, Line, 1)
        @test line == [Line(Point(1, 2), Point(3, 4)), Line(Point(3, 4), Point(5, 6))]

        triangles = connect(x, Triangle)
        @test triangles == [Triangle(Point(1, 2), Point(3, 4), Point(5, 6))]
        x = connect([1, 2, 3, 4, 5, 6, 7, 8], Point{2})
        tetrahedra = connect(x, NSimplex{4})
        @test tetrahedra == [Tetrahedron(x[1], x[2], x[3], x[4])]

        @testset "matrix non-copy point views" begin
            # point in row
            points = [1 2; 1 4; 66 77]
            comparison = [Point(1, 2), Point(1, 4), Point(66, 77)]
            @test connect(points, Point{2}) == comparison
            # point in column
            points = [1 1 66; 2 4 77]
            # huh, reinterpret array doesn't seem to like `==`
            @test all(((a,b),)-> a==b, zip(connect(points, Point{2}), comparison))
        end
    end

    @testset "face views" begin
        numbers = [1, 2, 3, 4, 5, 6]
        points = connect(numbers, Point{2})
        faces = connect([1, 2, 3], TriangleFace)
        triangles = connect(points, faces)
        @test triangles == [Triangle(Point(1, 2), Point(3, 4), Point(5, 6))]
        x = Point{3}(1.0)
        triangles = connect([x], [TriangleFace(1, 1, 1)])
        @test triangles == [Triangle(x, x, x)]
        points = connect([1, 2, 3, 4, 5, 6, 7, 8], Point{2})
        faces = connect([1, 2, 3, 4], SimplexFace{4})
        triangles = connect(points, faces)
        @test triangles == [Tetrahedron(points...)]
    end

    @testset "reinterpret" begin
        numbers = collect(reshape(1:6, 2, 3))
        points = reinterpret(Point{2, Int}, numbers)
        @test points[1] === Point(1, 2)
        @test points[2] === Point(3, 4)
        numbers[4] = 0
        @test points[2] === Point(3, 0)
    end
end

@testset "constructors" begin
    @testset "LineFace" begin

        points = connect([1, 2, 3, 4, 5, 6], Point{2})
        linestring = LineString(points)
        @test linestring == [Line(points[1], points[2]), Line(points[2], points[3])]

        points = rand(Point{2, Float64}, 4)
        linestring = LineString(points, 2)
        @test linestring == [Line(points[1], points[2]), Line(points[3], points[4])]

        linestring = LineString([points[1] => points[2], points[2] => points[3]])
        @test linestring == [Line(points[1], points[2]), Line(points[2], points[3])]

        faces = [1, 2, 3]
        linestring = LineString(points, faces)
        @test linestring == LineString([points[1] => points[2], points[2] => points[3]])
        a, b, c, d = Point(1, 2), Point(3, 4), Point(5, 6), Point(7, 8)
        points = [a, b, c, d]; faces = [1, 2, 3, 4]
        linestring = LineString(points, faces, 2)
        @test linestring == LineString([a => b, c => d])

        faces = [LineFace(1, 2)
        , LineFace(3, 4)]
        linestring = LineString(points, faces)
        @test linestring == LineString([a => b, c => d])
    end

    @testset "Polygon" begin

        points = connect([1, 2, 3, 4, 5, 6], Point{2})
        polygon = Polygon(points)
        @test polygon == Polygon(LineString(points))

        points = rand(Point{2, Float64}, 4)
        linestring = LineString(points, 2)
        @test Polygon(points, 2) == Polygon(linestring)

        faces = [1, 2, 3]
        polygon = Polygon(points, faces)
        @test polygon == Polygon(LineString(points, faces))

        a, b, c, d = Point(1, 2), Point(3, 4), Point(5, 6), Point(7, 8)
        points = [a, b, c, d]; faces = [1, 2, 3, 4]
        polygon = Polygon(points, faces, 2)
        @test polygon == Polygon(LineString(points, faces, 2))

        faces = [LineFace(1, 2), LineFace(3, 4)]
        polygon = Polygon(points, faces)
        @test polygon == Polygon(LineString(points, faces))
        @test ndims(polygon) === 2
    end

    @testset "Mesh" begin

        numbers = [1, 2, 3, 4, 5, 6]
        points = connect(numbers, Point{2})

        mesh = Mesh(points, [1,2,3])
        @test mesh == [Triangle(points...)]

        x = Point{3}(1.0)
        mesh = Mesh([x], [TriangleFace(1, 1, 1)])
        @test mesh == [Triangle(x, x, x)]

        points = connect([1, 2, 3, 4, 5, 6, 7, 8], Point{2})
        faces = connect([1, 2, 3, 4], SimplexFace{4})
        mesh = Mesh(points, faces)
        @test mesh == [Tetrahedron(points...)]

        points = rand(Point3f0, 8)
        tfaces = [GLTriangleFace(1, 2, 3), GLTriangleFace(5, 6, 7)]
        normals = rand(Vec3f0, 8)
        uv = rand(Vec2f0, 8)
        mesh = Mesh(points, tfaces)
        meshuv = Mesh(meta(points; uv=uv), tfaces)
        meshuvnormal = Mesh(meta(points; normals=normals, uv=uv), tfaces)

        @test mesh isa GLPlainMesh
        @test meshuv isa GLUVMesh3D
        @test meshuvnormal isa GLNormalUVMesh3D

    end

    @testset "Multi geometries" begin
        # coordinates from https://en.wikipedia.org/wiki/Well-known_text_representation_of_geometry#Geometric_objects
        points = Point{2, Int}[(10, 40), (40, 30), (20, 20), (30, 10)]
        multipoint = MultiPoint(points)
        @test size(multipoint) === size(points)
        @test multipoint[3] === points[3]

        linestring1 = LineString(Point{2, Int}[(10, 10), (20, 20), (10, 40)])
        linestring2 = LineString(Point{2, Int}[(40, 40), (30, 30), (40, 20), (30, 10)])
        multilinestring = MultiLineString([linestring1, linestring2])
        @test size(multilinestring) === (2,)
        @test multilinestring[1] === linestring1
        @test multilinestring[2] === linestring2

        polygon11 = Polygon(Point{2, Int}[(30, 20), (45, 40), (10, 40), (30, 20)])
        polygon12 = Polygon(Point{2, Int}[(15, 5), (40, 10), (10, 20), (5, 10), (15, 5)])
        multipolygon1 = MultiPolygon([polygon11, polygon12])
        @test size(multipolygon1) === (2,)
        @test multipolygon1[1] === polygon11
        @test multipolygon1[2] === polygon12

        polygon21 = Polygon(Point{2, Int}[(40, 40), (20, 45), (45, 30), (40, 40)])
        polygon22 = Polygon(LineString(Point{2, Int}[(20, 35), (10, 30), (10, 10), (30, 5), (45, 20), (20, 35)]),
            [LineString(Point{2, Int}[(30, 20), (20, 15), (20, 25), (30, 20)])])
        multipolygon2 = MultiPolygon([polygon21, polygon22])
        @test size(multipolygon2) === (2,)
        @test multipolygon2[1] === polygon21
        @test multipolygon2[2] === polygon22
    end

end

@testset "decompose/triangulation" begin
    primitive = Sphere(Point3f0(0), 1)
    @test ndims(primitive) === 3
    mesh = triangle_mesh(primitive)
    @test decompose(Point, mesh) isa Vector{Point3f0}
    @test decompose(Point, primitive) isa Vector{Point3f0}

    primitive = Rect2D(0, 0, 1, 1)
    mesh = triangle_mesh(primitive)

    @test decompose(Point, mesh) isa Vector{Point2f0}
    @test decompose(Point, primitive) isa Vector{Point2{Int}}

    primitive = Rect3D(0, 0, 0, 1, 1, 1)
    triangle_mesh(primitive)

    primitive = Sphere(Point3f0(0), 1)
    m_normal = normal_mesh(primitive)
    @test normals(m_normal) isa Vector{Vec3f0}
    primitive = Rect2D(0, 0, 1, 1)
    m_normal = normal_mesh(primitive)
    @test normals(m_normal) isa Vector{Vec3f0}
    primitive = Rect3D(0, 0, 0, 1, 1, 1)
    m_normal = normal_mesh(primitive)
    @test normals(m_normal) isa Vector{Vec3f0}

    points = decompose(Point2f0, Circle(Point2f0(0), 1))
    tmesh = triangle_mesh(points)
    @test normals(tmesh) == nothing

    m = GeometryBasics.mesh(Sphere(Point3f0(0), 1))
    @test normals(m) == nothing
    m_normals = pointmeta(m, Normal())
    @test normals(m_normals) isa Vector{Vec3f0}

    @test texturecoordinates(m) == nothing
    uv = decompose_uv(m)
    @test Rect(Point.(uv)) == Rect(0, 0, 1, 1)

    points = decompose(Point2f0, Circle(Point2f0(0), 1))
    m = GeometryBasics.mesh(points)
    @test coordinates(m) === points
end

@testset "Tests from GeometryTypes" begin
    include("geometrytypes.jl")
end

@testset "modifying meta" begin
    xx = rand(10)
    points = rand(Point3f0, 10)
    m = GeometryBasics.Mesh(meta(points, xx=xx), GLTriangleFace[(1,2,3), (3,4,5)])
    color = rand(10)
    m = pointmeta(m; color=color)

    @test hasproperty(m, :xx)
    @test hasproperty(m, :color)

    @test m.xx === xx
    @test m.color === color

    m, colpopt = GeometryBasics.pop_pointmeta(m, :color)
    m, xxpopt = GeometryBasics.pop_pointmeta(m, :xx)

    @test propertynames(m) == (:position,)
    @test colpopt === color
    @test xxpopt === xx

    @testset "creating meta" begin
        x = Point3f0[(1,3,4)]
        # no meta gets added, so should stay the same
        @test meta(x) === x
        @test meta(x, value=[1]).position === x
    end
    pos = Point2f0[(10, 2)]
    m = Mesh(meta(pos, uv=[Vec2f0(1, 1)]), [GLTriangleFace(1, 1, 1)])
    @test m.position === pos
end

@testset "mesh conversion" begin
    s = Sphere(Point3(0.0), 1.0)
    m = GeometryBasics.mesh(s)
    @test m isa Mesh{3, Float64}
    @test coordinates(m) isa Vector{Point{3, Float64}}
    @test GeometryBasics.faces(m) isa Vector{GLTriangleFace}
    # Check, that decompose isn't making a copy for matching eltype
    @test coordinates(m) === decompose(Point{3, Float64}, m)

    tmesh = triangle_mesh(m)
    @test tmesh isa GLPlainMesh
    @test coordinates(tmesh) === decompose(Point3f0, tmesh)

    nmesh = normal_mesh(m)
    @test nmesh isa GLNormalMesh
    @test metafree(coordinates(nmesh)) === decompose(Point3f0, nmesh)
    @test normals(nmesh) === decompose_normals(nmesh)

    m = GeometryBasics.mesh(s, pointtype=Point3f0)
    @test m isa Mesh{3, Float32}
    @test coordinates(m) isa Vector{Point3f0}
    @test GeometryBasics.faces(m) isa Vector{GLTriangleFace}
end

@testset "lines intersects" begin
    a = Line(Point(0.0, 0.0), Point(4.0, 1.0))
    b = Line(Point(0.0, 0.25), Point(3.0, 0.25))
    c = Line(Point(0.0, 0.25), Point(0.5, 0.25))
    d = Line(Point(0.0, 0.0), Point(0.0, 4.0))
    e = Line(Point(1.0, 0.0), Point(0.0, 4.0))
    f = Line(Point(5.0, 0.0), Point(6.0, 0.0))

    @test intersects(a, b) === (true, Point(1.0, 0.25))
    @test intersects(a, c) === (false, Point(0.0, 0.0))
    @test intersects(d, d) === (false, Point(0.0, 0.0))
    found, point = intersects(d, e)
    @test found && point ≈ Point(0.0, 4.0)
    @test intersects(a, f) === (false, Point(0.0, 0.0))
end

end  # testset "GeometryBasics"
