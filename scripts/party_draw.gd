extends RefCounted

const INK := Color("#243056")
const CREAM := Color("#fff8ea")
const CORAL := Color("#ff5d6c")
const GOLD := Color("#ffd23f")
const MINT := Color("#3ddc97")
const SKY := Color("#4dabff")
const ORANGE := Color("#ff8a3d")
const PINK := Color("#ff7ad9")
const PURPLE := Color("#b07cff")
const WHITE := Color("#ffffff")

const BALLOON_COLORS: Array[Color] = [
	Color("#ff5d6c"),
	Color("#ffd23f"),
	Color("#3ddc97"),
	Color("#4dabff"),
	Color("#b07cff"),
	Color("#ff8a3d"),
	Color("#ff7ad9"),
]


static func draw_sky(ci: CanvasItem, size: Vector2, time: float, sun_t: float) -> void:
	var top := Color("#49b8ff")
	var mid := Color("#b7ebff")
	var horizon := Color("#ffe7a3")
	var strips := 32
	var margin := 56.0
	var full_h := size.y + margin * 2.0
	var full_w := size.x + margin * 2.0
	for i in strips:
		var t := float(i) / float(strips - 1)
		var c := top.lerp(mid, smoothstep(0.0, 0.55, t)).lerp(horizon, smoothstep(0.42, 1.0, t))
		var y := -margin + full_h * float(i) / float(strips)
		ci.draw_rect(Rect2(-margin, y, full_w, full_h / float(strips) + 1.5), c)
	var sun_x := lerpf(size.x * 0.14, size.x * 0.86, clampf(sun_t, 0.0, 1.0))
	var sun_y := lerpf(size.y * 0.2, size.y * 0.58, sun_t * sun_t)
	var sun := Vector2(sun_x, sun_y)
	ci.draw_circle(sun + Vector2(0, 10), 64, Color(1, 0.78, 0.25, 0.28))
	ci.draw_circle(sun, 48, Color("#ffe566"))
	ci.draw_arc(sun, 48, 0, TAU, 40, INK, 6.0, true)
	draw_cloud(ci, Vector2(fposmod(time * 22.0, size.x + 300.0) - 150.0, size.y * 0.16), 1.05)
	draw_cloud(ci, Vector2(fposmod(time * 14.0 + 520.0, size.x + 340.0) - 170.0, size.y * 0.3), 0.7)
	_hill(ci, size, size.y * 0.78, 78.0, Color("#9ae884"))
	_hill(ci, size, size.y * 0.87, 54.0, Color("#5ec85a"))
	ci.draw_rect(Rect2(-margin, size.y * 0.92, full_w, size.y * 0.2 + margin), Color("#3eaf4e"))


static func _hill(ci: CanvasItem, size: Vector2, base_y: float, amp: float, color: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(-48, size.y + 48))
	pts.append(Vector2(-48, base_y))
	var steps := 14
	for i in steps + 1:
		var t := float(i) / float(steps)
		var x := lerpf(-48.0, size.x + 48.0, t)
		var y := base_y - sin(t * PI) * amp
		pts.append(Vector2(x, y))
	pts.append(Vector2(size.x + 48, size.y + 48))
	ci.draw_colored_polygon(pts, color)


static func draw_cloud(ci: CanvasItem, center: Vector2, scale: float) -> void:
	var c := Color(1, 1, 1, 0.94)
	ci.draw_circle(center + Vector2(0, 10) * scale, 26 * scale, Color(0.14, 0.18, 0.33, 0.1))
	ci.draw_circle(center + Vector2(-36, 6) * scale, 22 * scale, c)
	ci.draw_circle(center + Vector2(0, -2) * scale, 30 * scale, c)
	ci.draw_circle(center + Vector2(38, 6) * scale, 22 * scale, c)
	ci.draw_circle(center + Vector2(16, -18) * scale, 18 * scale, c)


static func draw_round_rect(ci: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	ci.draw_rect(Rect2(rect.position.x + r, rect.position.y, rect.size.x - r * 2.0, rect.size.y), color)
	ci.draw_rect(Rect2(rect.position.x, rect.position.y + r, rect.size.x, rect.size.y - r * 2.0), color)
	ci.draw_circle(rect.position + Vector2(r, r), r, color)
	ci.draw_circle(rect.position + Vector2(rect.size.x - r, r), r, color)
	ci.draw_circle(rect.position + Vector2(r, rect.size.y - r), r, color)
	ci.draw_circle(rect.position + Vector2(rect.size.x - r, rect.size.y - r), r, color)


static func draw_round_rect_outlined(ci: CanvasItem, rect: Rect2, radius: float, fill: Color, width: float = 7.0) -> void:
	var grow := width
	var outer := Rect2(rect.position - Vector2(grow, grow) * 0.5, rect.size + Vector2(grow, grow))
	draw_round_rect(ci, outer, radius + grow * 0.4, INK)
	draw_round_rect(ci, rect, radius, fill)


static func draw_balloon(ci: CanvasItem, radius: float, color: Color) -> void:
	var r := radius
	var string := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		string.append(Vector2(sin(t * PI) * 10.0, r * 0.72 + t * r * 0.95))
	ci.draw_polyline(string, INK, 4.0, true)
	ci.draw_circle(Vector2(0, r * 0.08), r, color.darkened(0.16))
	ci.draw_circle(Vector2(0, -r * 0.05), r * 0.97, color)
	ci.draw_circle(Vector2(-r * 0.32, -r * 0.36), r * 0.2, Color(1, 1, 1, 0.9))
	ci.draw_circle(Vector2(-r * 0.16, -r * 0.22), r * 0.08, Color(1, 1, 1, 0.55))
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-8, r * 0.72),
		Vector2(0, r * 0.96),
		Vector2(8, r * 0.72),
	]), color.darkened(0.08))
	ci.draw_arc(Vector2(0, -r * 0.03), r * 0.97, 0, TAU, 48, INK, 6.0, true)


static func draw_bat(ci: CanvasItem, color: Color) -> void:
	draw_round_rect(ci, Rect2(-16, 28, 32, 86), 14, INK)
	draw_round_rect(ci, Rect2(-11, 34, 22, 74), 10, color.darkened(0.12))
	ci.draw_circle(Vector2(0, 96), 16, Color(0, 0, 0, 0.12))
	ci.draw_circle(Vector2(0, -6), 52, INK)
	ci.draw_rect(Rect2(-52, -6, 104, 36), INK)
	ci.draw_circle(Vector2(0, -10), 44, color)
	ci.draw_rect(Rect2(-44, -8, 88, 30), color)
	ci.draw_rect(Rect2(-44, -6, 88, 16), Color(1, 1, 1, 0.88))
	ci.draw_circle(Vector2(-16, -24), 10, Color(1, 1, 1, 0.45))
	ci.draw_arc(Vector2(0, -10), 44, PI, TAU, 24, INK, 7.0, true)
	ci.draw_line(Vector2(-44, -8), Vector2(-44, 22), INK, 7.0, true)
	ci.draw_line(Vector2(44, -8), Vector2(44, 22), INK, 7.0, true)
	ci.draw_line(Vector2(-44, 22), Vector2(44, 22), INK, 7.0, true)
	ci.draw_line(Vector2(-11, 40), Vector2(-11, 96), Color(1, 1, 1, 0.35), 3.0, true)


static func draw_apple(ci: CanvasItem, radius: float, color: Color) -> void:
	ci.draw_circle(Vector2(0, 5), radius, color.darkened(0.14))
	ci.draw_circle(Vector2.ZERO, radius, color)
	ci.draw_circle(Vector2(-radius * 0.28, -radius * 0.28), radius * 0.16, Color(1, 1, 1, 0.75))
	ci.draw_line(Vector2(0, -radius * 0.72), Vector2(2, -radius * 1.2), Color("#6b3a1f"), 5.0, true)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(2, -radius * 1.05),
		Vector2(radius * 0.75, -radius * 1.28),
		Vector2(radius * 0.28, -radius * 0.78),
	]), Color("#3eaf4e"))
	ci.draw_arc(Vector2.ZERO, radius, 0, TAU, 28, INK, 5.0, true)


static func draw_star(ci: CanvasItem, radius: float, color: Color) -> void:
	var pts: Array[Vector2] = []
	for i in 10:
		var ang := -PI / 2.0 + float(i) * PI / 5.0
		var rad := radius if i % 2 == 0 else radius * 0.42
		pts.append(Vector2(cos(ang), sin(ang)) * rad)
	var poly := PackedVector2Array()
	poly.append(Vector2.ZERO)
	for p in pts:
		poly.append(p)
	poly.append(pts[0])
	ci.draw_colored_polygon(poly, color)
	var outline := PackedVector2Array()
	for p in pts:
		outline.append(p)
	outline.append(pts[0])
	ci.draw_polyline(outline, INK, 5.0, true)


static func draw_tree(ci: CanvasItem, scale: float) -> void:
	draw_round_rect(ci, Rect2(-22 * scale, -20 * scale, 44 * scale, 168 * scale), 16 * scale, Color("#6b3a1f"))
	draw_round_rect(ci, Rect2(-14 * scale, -8 * scale, 28 * scale, 148 * scale), 12 * scale, Color("#a86a3c"))
	var blobs: Array[Vector2] = [
		Vector2(0, -150),
		Vector2(-70, -110),
		Vector2(72, -108),
		Vector2(-36, -186),
		Vector2(40, -188),
		Vector2(0, -120),
		Vector2(-104, -78),
		Vector2(108, -74),
	]
	var radii: Array[float] = [78, 64, 66, 58, 56, 70, 46, 48]
	var greens: Array[Color] = [Color("#2f8f3a"), Color("#67d36a"), Color("#3aaa45")]
	for i in blobs.size():
		ci.draw_circle(blobs[i] * scale, (radii[i] + 7.0) * scale, INK)
	for i in blobs.size():
		ci.draw_circle(blobs[i] * scale, radii[i] * scale, greens[i % greens.size()])
	ci.draw_circle(Vector2(-30, -170) * scale, 16 * scale, Color(1, 1, 1, 0.28))


static func draw_basket(ci: CanvasItem, width: float, height: float) -> void:
	var pts := PackedVector2Array([
		Vector2(-width * 0.48, -height * 0.45),
		Vector2(width * 0.48, -height * 0.45),
		Vector2(width * 0.36, height * 0.5),
		Vector2(-width * 0.36, height * 0.5),
	])
	ci.draw_colored_polygon(pts, Color("#d39245"))
	var inner := PackedVector2Array([
		Vector2(-width * 0.4, -height * 0.32),
		Vector2(width * 0.4, -height * 0.32),
		Vector2(width * 0.3, height * 0.36),
		Vector2(-width * 0.3, height * 0.36),
	])
	ci.draw_colored_polygon(inner, Color("#f0c27a"))
	ci.draw_line(Vector2(-width * 0.52, -height * 0.48), Vector2(width * 0.52, -height * 0.48), INK, 16.0, true)
	ci.draw_line(Vector2(-width * 0.52, -height * 0.48), Vector2(width * 0.52, -height * 0.48), Color("#e8b15a"), 8.0, true)


static func draw_car(ci: CanvasItem, color: Color) -> void:
	ci.draw_circle(Vector2(0, 10), 34, Color(0, 0, 0, 0.14))
	for p in [Vector2(-32, -34), Vector2(32, -34), Vector2(-32, 36), Vector2(32, 36)]:
		ci.draw_circle(p, 14, INK)
		ci.draw_circle(p, 7, Color("#d5e4ef"))
	draw_round_rect_outlined(ci, Rect2(-26, -52, 52, 108), 20, color, 7.0)
	draw_round_rect(ci, Rect2(-18, -30, 36, 44), 12, color.lightened(0.18))
	draw_round_rect(ci, Rect2(-16, -24, 32, 18), 6, Color("#dff6ff"))
	ci.draw_circle(Vector2(-12, -46), 5, Color("#fff4c2"))
	ci.draw_circle(Vector2(12, -46), 5, Color("#fff4c2"))
	ci.draw_rect(Rect2(-18, 28, 36, 8), Color(1, 1, 1, 0.35))


static func draw_button(ci: CanvasItem, radius: float, fill: Color) -> void:
	ci.draw_circle(Vector2(0, 8), radius, Color(0, 0, 0, 0.16))
	ci.draw_circle(Vector2.ZERO, radius, INK)
	ci.draw_circle(Vector2(0, -2), radius - 7.0, fill)


static func draw_house(ci: CanvasItem, size: float) -> void:
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-size, size * 0.12),
		Vector2(0, -size * 0.78),
		Vector2(size, size * 0.12),
	]), WHITE)
	ci.draw_rect(Rect2(-size * 0.62, size * 0.1, size * 1.24, size * 0.62), WHITE)
	ci.draw_rect(Rect2(-size * 0.16, size * 0.32, size * 0.32, size * 0.4), INK)


static func draw_replay(ci: CanvasItem, radius: float) -> void:
	ci.draw_arc(Vector2.ZERO, radius * 0.46, 0.7, TAU - 0.15, 28, WHITE, 8.0, true)
	var ang := 0.55
	var tip := Vector2(cos(ang), sin(ang)) * radius * 0.46
	var tangent := Vector2(-sin(ang), cos(ang))
	ci.draw_colored_polygon(PackedVector2Array([
		tip + tangent * 14.0,
		tip - tangent * 12.0 + Vector2(cos(ang), sin(ang)) * 6.0,
		tip - tangent * 2.0 - Vector2(cos(ang), sin(ang)) * 16.0,
	]), WHITE)


static func draw_text(ci: CanvasItem, at: Vector2, text: String, size: int, fill: Color) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var baseline := at + Vector2(-measured.x * 0.5, measured.y * 0.32)
	var offsets: Array[Vector2] = [
		Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3),
		Vector2(-3, -3), Vector2(3, -3), Vector2(-3, 3), Vector2(3, 3),
	]
	for off in offsets:
		ci.draw_string(font, baseline + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, INK)
	ci.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, fill)


static func draw_pips(ci: CanvasItem, origin: Vector2, count: int, filled: int, color: Color) -> void:
	for i in count:
		var center := origin + Vector2(float(i) * 26.0, 0)
		var on := i < filled
		ci.draw_circle(center, 9, color if on else Color(1, 1, 1, 0.38))
		ci.draw_arc(center, 9, 0, TAU, 16, INK, 3.0, true)


static func draw_end_card(ci: CanvasItem, size: Vector2, title: String, score_text: String) -> void:
	var card := Rect2(size.x * 0.5 - 300.0, size.y * 0.12, 600.0, 340.0)
	draw_round_rect(ci, Rect2(card.position + Vector2(-10, 12), card.size), 40.0, Color(0.08, 0.1, 0.18, 0.28))
	draw_round_rect(ci, card.grow(8.0), 40.0, INK)
	draw_round_rect(ci, card, 34.0, CREAM)
	draw_text(ci, Vector2(size.x * 0.5, card.position.y + 92.0), title, 68, CORAL)
	draw_text(ci, Vector2(size.x * 0.5, card.position.y + 210.0), score_text, 108, INK)
