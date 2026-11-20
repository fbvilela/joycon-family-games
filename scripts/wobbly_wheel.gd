extends Node2D

const Draw := preload("res://scripts/party_draw.gd")
const IconButton := preload("res://scripts/icon_button.gd")
const ROUND := 45.0
const SCROLL := 280.0

var score := 0
var time_left := ROUND
var elapsed := 0.0
var celebrating := false
var car_x := 640.0
var car_v := 0.0
var car_y := 520.0
var steer := 0.0
var scroll := 0.0
var world: Node2D
var car: Node2D
var stars: Array = []
var score_label: Label
var replay_button: Node2D
var home_button: Node2D
var _spawn := 0.2
var _leaving := false
var _rain := 0.0


func _ready() -> void:
	if MotionInput.demo:
		seed(11)
	else:
		randomize()
	_build()
	MotionInput.point_tap.connect(_on_tap)


func _size() -> Vector2:
	var size := get_viewport_rect().size
	if size.x < 32.0:
		return Vector2(1280, 720)
	return size


func _build() -> void:
	world = Node2D.new()
	add_child(world)
	var road := Road.new()
	road.host = self
	world.add_child(road)
	car = CarArt.new()
	car.z_index = 4
	world.add_child(car)
	var hud := CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	var pips := HudArt.new()
	pips.host = self
	hud.add_child(pips)
	score_label = Label.new()
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 64)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_label.add_theme_color_override("font_outline_color", Draw.INK)
	score_label.add_theme_constant_override("outline_size", 16)
	score_label.custom_minimum_size = Vector2(160, 84)
	score_label.pivot_offset = Vector2(80, 42)
	hud.add_child(score_label)
	var overlay := CanvasLayer.new()
	overlay.layer = 8
	add_child(overlay)
	var end := EndCard.new()
	end.host = self
	overlay.add_child(end)
	replay_button = IconButton.new()
	replay_button.kind = "replay"
	replay_button.fill = Draw.MINT
	replay_button.visible = false
	overlay.add_child(replay_button)
	home_button = IconButton.new()
	home_button.kind = "home"
	home_button.fill = Draw.GOLD
	home_button.visible = false
	overlay.add_child(home_button)
	_layout()
	_seed_stars()
	_refresh()


func _layout() -> void:
	var size := _size()
	car_y = size.y * 0.72
	if not celebrating and absf(car_x - 640.0) < 0.1 and elapsed < 0.01:
		car_x = size.x * 0.5
	score_label.position = Vector2(size.x * 0.5 - 80.0, 8.0)
	replay_button.position = Vector2(size.x * 0.38, size.y * 0.8)
	home_button.position = Vector2(size.x * 0.62, size.y * 0.8)
	car.position = Vector2(car_x, car_y)


func _process(delta: float) -> void:
	elapsed += delta
	var size := _size()
	if not celebrating:
		time_left = maxf(time_left - delta, 0.0)
		if MotionInput.demo:
			steer = sin(elapsed * 1.4)
			car_x = size.x * 0.5 + steer * size.x * 0.28 + sin(elapsed * 9.0) * 8.0
			car_v = cos(elapsed * 1.4) * size.x * 0.28 * 1.4
		else:
			steer = clampf(MotionInput.tilt[0].x + MotionInput.tilt[1].x, -1.0, 1.0)
			var target := size.x * 0.5 + steer * size.x * 0.28
			var accel := (target - car_x) * 26.0 - car_v * 6.5
			car_v += accel * delta
			car_x += car_v * delta
		var left := size.x * 0.16
		var right := size.x * 0.84
		if car_x < left:
			car_x = left
			car_v = absf(car_v) * 0.25
		elif car_x > right:
			car_x = right
			car_v = -absf(car_v) * 0.25
		car.position = Vector2(car_x, car_y)
		car.rotation = steer * 0.42
		var squash := 1.0 + clampf(absf(car_v) / 900.0, 0.0, 0.12)
		car.scale = Vector2(1.0 / squash, squash)
		scroll += SCROLL * delta
		_spawn -= delta
		if _spawn <= 0.0:
			_spawn = 0.85
			_spawn_star()
		_move_stars(delta)
		if time_left <= 0.0:
			_celebrate()
	else:
		_rain -= delta
		if _rain <= 0.0:
			_rain = 0.1
			_bits(Vector2(randf_range(40, size.x - 40), -10), Draw.GOLD)


func _seed_stars() -> void:
	var size := _size()
	for i in 3:
		var y := car_y - 130.0 - float(i) * 170.0
		var travel := maxf(car_y - y, 0.0) / SCROLL
		var x := size.x * (0.3 + float(i) * 0.18)
		if MotionInput.demo:
			x = size.x * 0.5 + sin(travel * 1.4) * size.x * 0.28
		var star := StarBit.new()
		star.position = Vector2(x, y)
		star.z_index = 3
		world.add_child(star)
		stars.append(star)


func _spawn_star() -> void:
	var size := _size()
	var x := randf_range(size.x * 0.24, size.x * 0.76)
	if MotionInput.demo:
		var travel := (car_y + 30.0) / SCROLL
		x = size.x * 0.5 + sin((elapsed + travel) * 1.4) * size.x * 0.28
	var star := StarBit.new()
	star.position = Vector2(x, -36.0)
	star.z_index = 3
	world.add_child(star)
	stars.append(star)


func _move_stars(delta: float) -> void:
	var kept: Array = []
	for star in stars:
		if not is_instance_valid(star):
			continue
		if star.got:
			kept.append(star)
			continue
		star.position.y += SCROLL * delta
		if absf(star.position.x - car_x) < 96.0 and absf(star.position.y - car_y) < 70.0:
			var burst_at: Vector2 = star.position
			star.visible = false
			star.queue_free()
			score += 1
			_refresh()
			_bump()
			AudioFx.play("ding")
			_bits(burst_at, Draw.GOLD)
			continue
		elif star.position.y > _size().y + 40.0:
			star.queue_free()
			continue
		kept.append(star)
	stars = kept


func _bits(at: Vector2, color: Color) -> void:
	for _i in 10:
		var bit := Bit.new()
		bit.position = at
		bit.color = color if randf() > 0.4 else Color.WHITE
		var ang := randf() * TAU
		bit.vel = Vector2(cos(ang), sin(ang)) * randf_range(80.0, 280.0)
		world.add_child(bit)


func _refresh() -> void:
	score_label.text = str(score)


func _bump() -> void:
	var tw := create_tween()
	score_label.scale = Vector2(0.75, 0.75)
	tw.tween_property(score_label, "scale", Vector2(1.14, 1.14), 0.09).set_trans(Tween.TRANS_BACK)
	tw.tween_property(score_label, "scale", Vector2.ONE, 0.14)


func _celebrate() -> void:
	if celebrating:
		return
	celebrating = true
	AudioFx.play("cheer")
	replay_button.visible = true
	home_button.visible = true


func _on_tap(player: int, _aim: Vector2, screen_pos: Vector2) -> void:
	if not celebrating:
		return
	var at := screen_pos
	if at == Vector2.ZERO:
		at = replay_button.global_position if player == 0 else home_button.global_position
	_click_at(at)


func _click_at(pos: Vector2) -> void:
	if pos.distance_to(replay_button.global_position) < 80.0:
		_go(true)
	elif pos.distance_to(home_button.global_position) < 80.0:
		_go(false)


func _go(again: bool) -> void:
	if _leaving:
		return
	_leaving = true
	if again:
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if not celebrating:
		return
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_click_at((event as InputEventMouseButton).position)
	elif event.is_action_pressed("ui_cancel"):
		_go(false)
	elif event.is_action_pressed("ui_accept"):
		_go(true)


func debug_car_x() -> float:
	return car_x


class Road extends Node2D:
	const Draw := preload("res://scripts/party_draw.gd")
	var host

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var size: Vector2 = host._size()
		var sun := 1.0 - clampf(host.time_left / host.ROUND, 0.0, 1.0)
		Draw.draw_sky(self, size, host.elapsed, sun)
		var half := size.x * 0.38
		var left := size.x * 0.5 - half
		draw_rect(Rect2(left, -30, half * 2.0, size.y + 60), Color("#7d8b99"))
		draw_rect(Rect2(left, -30, 22, size.y + 60), Color("#ffe566"))
		draw_rect(Rect2(left + half * 2.0 - 22, -30, 22, size.y + 60), Color("#ffe566"))
		draw_rect(Rect2(left - 8, -30, 8, size.y + 60), Draw.INK)
		draw_rect(Rect2(left + half * 2.0, -30, 8, size.y + 60), Draw.INK)
		var offset := fmod(host.scroll, 90.0)
		var y := -90.0 + offset
		while y < size.y + 20.0:
			draw_round_rect_local(Vector2(size.x * 0.5 - 10.0, y), Vector2(20, 42), Color("#fff8ea"))
			y += 90.0
		var bush := fmod(host.scroll, 160.0)
		var by := -80.0 + bush
		while by < size.y + 40.0:
			draw_circle(Vector2(left - 54.0, by), 28, Color("#3eaf4e"))
			draw_circle(Vector2(left + half * 2.0 + 54.0, by + 40.0), 24, Color("#2f8f3a"))
			by += 160.0

	func draw_round_rect_local(at: Vector2, box: Vector2, color: Color) -> void:
		draw_rect(Rect2(at, box), color)


class CarArt extends Node2D:
	const Draw := preload("res://scripts/party_draw.gd")

	func _draw() -> void:
		Draw.draw_car(self, Draw.CORAL)


class StarBit extends Node2D:
	const Draw := preload("res://scripts/party_draw.gd")
	var got := false
	var phase := 0.0

	func _process(delta: float) -> void:
		phase += delta
		if got:
			scale = scale.lerp(Vector2.ZERO, 0.25)
			modulate.a = maxf(modulate.a - delta * 3.0, 0.0)
			if scale.x < 0.05:
				queue_free()
		else:
			rotation = sin(phase * 2.0) * 0.15
			queue_redraw()

	func _draw() -> void:
		Draw.draw_star(self, 30.0, Draw.GOLD)


class HudArt extends Node2D:
	const Draw := preload("res://scripts/party_draw.gd")
	var host

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if host.celebrating:
			return
		var size: Vector2 = host._size()
		var filled := int(ceil(host.time_left / host.ROUND * 10.0))
		Draw.draw_pips(self, Vector2(size.x * 0.5 - 117.0, 100.0), 10, filled, Draw.GOLD)


class EndCard extends Node2D:
	const Draw := preload("res://scripts/party_draw.gd")
	var host

	func _process(_delta: float) -> void:
		if host.celebrating:
			queue_redraw()

	func _draw() -> void:
		if not host.celebrating:
			return
		Draw.draw_end_card(self, host._size(), "Stars!", str(host.score))


class Bit extends Node2D:
	var vel := Vector2.ZERO
	var color := Color.WHITE
	var life := 0.0

	func _process(delta: float) -> void:
		life += delta
		vel.y += 700.0 * delta
		position += vel * delta
		rotation += delta * 4.0
		if life > 0.7:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-6, -10, 12, 20), color)
