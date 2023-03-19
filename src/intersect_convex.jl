abstract type ConvexPolygonIntersectionAlgorithm end

struct PointSearchAlg <: ConvexPolygonIntersectionAlgorithm end
struct ChasingEdgesAlg <: ConvexPolygonIntersectionAlgorithm end
struct WeilerAthertonAlg <: ConvexPolygonIntersectionAlgorithm end

"""
    intersect_convex(polygon1, polygon2, alg=ChasingEdgesAlg())

Find the intersection points of convex polygons `polygon1` and `polygon2`.
They are not guaranteed to be unique.

A major assumption is that convex polygons have only one area of intersection.
This fails in the general case with non-convex polgyons. 
For that, see the polygon clipping algorithms such as Weiler-Atherton.

`alg` can either be `ChasingEdgesAlg()` or `PointSearchAlg()`

For `n` and `m` vertices on polygon 1 and 2 respectively:
- `ChasingEdgesAlg()`
    - Time complexity: `O(n+m)`. 
    - Algorithm is from "A New Linear Algorithm for Intersecting Convex Polygons" (1981) by Joseph O'Rourke et. al.
    - Reference: https://www.cs.jhu.edu/~misha/Spring16/ORourke82.pdf
- `PointSearchAlg()`
    - Time complexity: `O(nm)`. 
    - For general non-intersecting polygons, the intersection points are valid but the order is not.
    - Algorithm:
    
        - intersection of all edge pairs in O(nm) time.
        - Checks all point in polgyons in O(nm)+O(mn) time.
        - Sort the final result counter-clockwise.
"""
intersect_convex(polygon1::Polygon, polygon2::Polygon) = intersect_convex(polygon1, polygon2, ChasingEdgesAlg())

function intersect_convex(polygon1::Polygon, polygon2::Polygon, ::PointSearchAlg)
    #https://www.swtestacademy.com/intersection-convex-polygons-algorithm/
    intersection_points = intersect_edges(polygon1, polygon2)
    
    i1_in_2 = [point_in_polygon(p, polygon2) for p in polygon1]
    p1_in_2 = polygon1[i1_in_2]
    i2_in_1 = [point_in_polygon(p, polygon1) for p in polygon2]
    p2_in_1 = polygon2[i2_in_1]

    if isempty(intersection_points) && isempty(p1_in_2) && isempty(p2_in_1)
        return intersection_points
    end

    points = vcat(intersection_points, p1_in_2, p2_in_1)
    points = sort_counter_clockwise(points)
    points
end

function intersect_convex(polygon1::Polygon{T}, polygon2::Polygon{T}, ::ChasingEdgesAlg) where T
    n = length(polygon1)
    m = length(polygon2)
    points = Point2D{T}[]
    # order clockwise -> counter-clockwise from original paper does not seem to give correct results
    if is_counter_clockwise(polygon1)
        polygon1 = reverse(polygon1)
    end
    if is_counter_clockwise(polygon2)
        polygon2 = reverse(polygon2)
    end
    poly1_in_2 = false
    poly2_in_1 = false
    i = 1
    j = 1
    for k in 1:(2 * (m + n))
        i_prev = i == 1 ? n : i - 1
        j_prev = j == 1 ? m : j - 1
        edge1 = (polygon1[i_prev], polygon1[i])
        edge2 = (polygon2[j_prev], polygon2[j])
        inter = intersect_geometry(edge1, edge2)
        is_colinear = cross_product(edge1, edge2) ≈ 0.0
        if !isnothing(inter) && !is_colinear
            is_second_iter = k > (m + n)
            if length(points) > 1 && (all(inter .≈ points[1]) && is_second_iter)
                poly1_in_2 = false
                poly2_in_1 = false
                break
            end
            push!(points, inter)
            poly1_in_2 = in_half_plane(polygon1[i], edge2)
            poly2_in_1 = !poly1_in_2 #&& in_half_plane(polygon2[j], edge1)
        end
        advance_1 = false 
        if cross_product(edge1, edge2) >= 0 # cross_product swapped compared to original paper
            advance_1 = !(in_half_plane(polygon1[i], edge2))
        else
            advance_1 = in_half_plane(polygon2[j], edge1)
        end
        if advance_1
            if poly1_in_2
                push!(points, polygon1[i])
            end
            i = i % n + 1
        else # advance_2
            if poly2_in_1
                push!(points, polygon2[j])
            end
            j = j % m + 1
        end
    end
    if isempty(points)
        if point_in_polygon(polygon1[1], polygon2)
            return polygon1
        elseif  point_in_polygon(polygon2[1], polygon1)
            return polygon2
        end
    end
    points
end

function intersect_convex(polygon1::Polygon{T}, polygon2::Polygon{T}, ::WeilerAthertonAlg) where T
    regions = intersect_geometry(polygon1, polygon2)
    if isempty(regions)
        return Point2D{T}[]
    end
    @assert length(regions) == 1 "Convex polygons can only have one region of intersection; $(length(regions)) found"
    regions[1]
end