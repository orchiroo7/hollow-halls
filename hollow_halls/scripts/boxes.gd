extends RefCounted

const Look := preload("res://scripts/look.gd")


static func make_box(size: Vector2, color: Color, outline := 0.0) -> Polygon2D:
    var p := Polygon2D.new()
    p.polygon = rect_points(size)
    p.color = color
    if outline > 0.0:
        var e := Polygon2D.new()
        e.polygon = rect_points(size + Vector2(outline, outline) * 2.0)
        e.color = Look.INK
        e.show_behind_parent = true
        p.add_child(e)
    return p


static func rect_points(size: Vector2) -> PackedVector2Array:
    var h := size * 0.5
    return PackedVector2Array([
        Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)
    ])


static func gradient_box(size: Vector2, top: Color, bottom: Color) -> Polygon2D:
    var p := make_box(size, top)
    p.vertex_colors = PackedColorArray([top, top, bottom, bottom])
    return p
