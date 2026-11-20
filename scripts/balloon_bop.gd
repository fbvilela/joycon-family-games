extends Node2D

const Draw := preload("res://scripts/party_draw.gd")
const IconButton := preload("res://scripts/icon_button.gd")
const ROUND := 75.0

var score := 0
var time_left := ROUND
var elapsed := 0.0
var celebrating := false
var world: Node2D
var effects: Node2D
var bats: Array = []
var balloons: Array = []
var score_label: Label
var replay_button: Node2D
var home_button: Node2D
var _spawn_wait := 0.35
var _demo_wait := 0.4
var _demo_player := 1
var _shake := 0.0
var _shake_mag := 0.0
var _rain := 0.0
var _leaving := false


func _ready() -> void:
	if MotionInput.demo:
		seed(7)
	else:
		randomize()
	_build()
	MotionInput.swing.connect(_on_swing)
	MotionInput.point_tap.connect(_on_tap)
	for i in 8:
		var col := i % 4
		var row := int(i / 4.0)
		var size := _size()
		_spawn_balloon(
			Vector2(size.x * (0.16 + float(col) * 0.22), size.y * (0.36 + float(row) * 0.2)),
			randf_range(58.0, 78.0),
			Draw.BALLOON_COLORS[i % Draw.BALLOON_COLORS.size()]
		)


func _size() -> Vector2:
	var size := get_viewport_rect().size
	if size.x < 32.0:
		return Vector2(1280, 720)
	return size


func _build() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	var sky := PartySky.new()
	sky.host = self
	sky.z_index = 0
	world.add_child(sky)
	effects = Node2D.new()
	effects.z_index = 3
	world.add_child(effects)
	for player in 2:
		var bat := Bat.new()
		bat.player = player
		bat.z_index = 5
		bat.color = Draw.CORAL if player == 0 else Draw.GOLD
		world.add_child(bat)
		bats.append(bat)
	_layout_bats()
	var hud := CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	var art := HudArt.new()
	art.host = self
	hud.add_child(art)
	score_label = Label.new()
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 72)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_label.add_theme_color_override("font_outline_color", Draw.INK)
	score_label.add_theme_constant_override("outline_size", 16)
	score_label.custom_minimum_size = Vector2(180, 96)
	score_label.pivot_offset = Vector2(90, 48)
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
	replay_button.z_index = 2
	overlay.add_child(replay_button)
	home_button = IconButton.new()
	home_button.kind = "home"
	home_button.fill = Draw.GOLD
	home_button.visible = false
	home_button.z_index = 2
	overlay.add_child(home_button)
	_layout_hud()
	_refresh_score()


func _layout_bats() -> void:
	var size := _size()
	bats[1].position = Vector2(size.x * 0.16, size.y * 0.8)
	bats[1].rest = 0.5
	bats[0].position = Vector2(size.x * 0.84, size.y * 0.8)
	bats[0].rest = -0.5


func _layout_hud() -> void:
	var size := _size()
	score_label.position = Vector2(size.x * 0.5 - 90.0, 8.0)
	replay_button.position = Vector2(size.x * 0.38, size.y * 0.8)
	home_button.position = Vector2(size.x * 0.62, size.y * 0.8)


func _process(delta: float) -> void:
	elapsed += delta
	if _shake > 0.0:
		_shake = maxf(_shake - delta, 0.0)
		world.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_mag * (_shake / 0.22)
	else:
		world.position = Vector2.ZERO
	if not celebrating:
		time_left = maxf(time_left - delta, 0.0)
		_spawn_wait -= delta
		if _spawn_wait <= 0.0:
			_spawn_wait = randf_range(0.55, 1.05)
			_spawn_from_top()
		_move_balloons(delta)
		if MotionInput.demo:
			_demo(delta)
		if time_left <= 0.0:
			_celebrate()
	else:
		_rain -= delta
		if _rain <= 0.0:
			_rain = 0.07
			var size := _size()
			_burst(Vector2(randf_range(30.0, size.x - 30.0), -16.0), Draw.BALLOON_COLORS[randi() % Draw.BALLOON_COLORS.size()], 8)


func _demo(delta: float) -> void:
	_demo_wait -= delta
	if _demo_wait > 0.0:
		return
	_demo_wait = 0.85
	var origin: Vector2 = bats[_demo_player].global_position
	var dir := Vector2(0, -1)
	var target: Node2D = _closest_balloon(_demo_player)
	if target != null:
		dir = target.global_position - origin
	MotionInput.inject_swing(_demo_player, 1.0, dir)
	_demo_player = 1 - _demo_player


func _move_balloons(delta: float) -> void:
	var size := _size()
	for balloon in balloons:
		if balloon.popping:
			continue
		balloon.phase += delta
		balloon.vy += 16.0 * delta
		balloon.vy = clampf(balloon.vy, -170.0, 125.0)
		balloon.position += Vector2(balloon.vx, balloon.vy) * delta
		if balloon.position.y > size.y * 0.9:
			balloon.position.y = size.y * 0.9
			balloon.vy = -absf(balloon.vy) * 0.42 - 60.0
		if balloon.position.y < 250.0 and balloon.vy < 0.0:
			balloon.position.y = 250.0
			balloon.vy = absf(balloon.vy) + 30.0
		if balloon.position.x < 70.0:
			balloon.vx = absf(balloon.vx) + 6.0
		elif balloon.position.x > size.x - 70.0:
			balloon.vx = -absf(balloon.vx) - 6.0
		var w := sin(balloon.phase * 3.1 + balloon.position.x * 0.01)
		balloon.scale = Vector2(1.0 + w * 0.07, 1.0 - w * 0.07)
		balloon.rotation = sin(balloon.phase * 1.25) * 0.05


func _spawn_from_top() -> void:
	var size := _size()
	var balloon := _spawn_balloon(
		Vector2(randf_range(120.0, size.x - 120.0), 250.0),
		randf_range(56.0, 76.0),
		Draw.BALLOON_COLORS[randi() % Draw.BALLOON_COLORS.size()]
	)
	balloon.vy = randf_range(50.0, 90.0)


func _spawn_balloon(at: Vector2, radius: float, color: Color) -> Node2D:
	var balloon := Balloon.new()
	balloon.position = at
	balloon.radius = radius
	balloon.color = color
	balloon.vy = randf_range(46.0, 90.0)
	balloon.vx = randf_range(-16.0, 16.0)
	balloon.phase = randf() * TAU
	balloon.z_index = 2
	world.add_child(balloon)
	balloons.append(balloon)
	return balloon


func _on_swing(player: int, _strength: float, direction: Vector2) -> void:
	if celebrating or player < 0 or player > 1:
		return
	var bat: Bat = bats[player]
	bat.wobble = false
	var sweep := 2.15 if player == 1 else -2.15
	var tw := create_tween()
	tw.tween_property(bat, "rotation", bat.rest + sweep, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(bat, "rotation", bat.rest, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: bat.wobble = true)
	var dir := _aim_dir(player, direction)
	var reach := _size().y * 0.86
	var radius := _size().x * 0.15
	var swoosh := Swoosh.new()
	swoosh.position = bat.position
	swoosh.dir = dir
	swoosh.color = bat.color
	swoosh.length = reach
	swoosh.width = radius
	effects.add_child(swoosh)
	AudioFx.play("whoosh")
	var origin := bat.global_position
	var dest := origin + dir * reach
	for balloon in balloons.duplicate():
		if balloon.popping:
			continue
		if _hits(balloon.global_position, origin, dest, radius + balloon.radius * 0.45):
			_pop(balloon, player, true)


func _on_tap(player: int, _aim: Vector2, screen_pos: Vector2) -> void:
	if celebrating:
		_click_at(screen_pos if screen_pos != Vector2.ZERO else _button_fallback(player))


func _aim_dir(player: int, raw: Vector2) -> Vector2:
	var dir := raw.normalized() if raw.length() > 0.01 else Vector2.UP
	var bat_pos := (bats[player] as Node2D).global_position
	var to_center := (_size() * 0.5 - bat_pos).normalized()
	if dir.dot(to_center) < 0.2:
		return to_center
	return dir


func _hits(point: Vector2, a: Vector2, b: Vector2, radius: float) -> bool:
	var ab := b - a
	var t := 0.0
	if ab.length_squared() > 0.001:
		t = clampf((point - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return a.lerp(b, t).distance_to(point) <= radius


func _pop(balloon: Node2D, player: int, award: bool) -> void:
	if balloon.popping:
		return
	balloon.popping = true
	balloons.erase(balloon)
	if award:
		score += 1
		_refresh_score()
		_bump_score()
		var floater := Floater.new()
		var side := 86.0 if player == 0 else -86.0
		floater.position = balloon.position + Vector2(side, -10)
		floater.fill = Draw.CORAL if player == 0 else Draw.GOLD
		effects.add_child(floater)
	AudioFx.play("pop")
	_shake = 0.22
	_shake_mag = 18.0
	_burst(balloon.position, balloon.color, 26)
	var ring := Ring.new()
	ring.position = balloon.position
	effects.add_child(ring)
	var tw := create_tween()
	tw.tween_property(balloon, "scale", Vector2(1.4, 0.55), 0.07)
	tw.tween_property(balloon, "scale", Vector2(0.16, 1.65), 0.1)
	tw.tween_callback(balloon.queue_free)
	var fade := create_tween()
	fade.tween_interval(0.08)
	fade.tween_property(balloon, "modulate:a", 0.0, 0.1)


func _burst(at: Vector2, color: Color, count: int) -> void:
	for _i in count:
		var bit := Bit.new()
		bit.position = at
		bit.color = Draw.BALLOON_COLORS[randi() % Draw.BALLOON_COLORS.size()] if randf() > 0.35 else color
		var ang := randf() * TAU
		var speed := randf_range(180.0, 620.0)
		bit.vel = Vector2(cos(ang), sin(ang)) * speed + Vector2(0, -80)
		bit.spin = randf_range(-8.0, 8.0)
		bit.box = Vector2(randf_range(11.0, 18.0), randf_range(16.0, 30.0))
		bit.z_index = 4
		effects.add_child(bit)


func _closest_balloon(player: int) -> Node2D:
	var origin: Vector2 = bats[player].global_position
	var best: Node2D = null
	var best_d := 100000.0
	for balloon in balloons:
		if balloon.popping:
			continue
		var d := origin.distance_to(balloon.global_position)
		if d < best_d:
			best_d = d
			best = balloon
	return best


func _refresh_score() -> void:
	score_label.text = str(score)


func _bump_score() -> void:
	var tw := create_tween()
	score_label.scale = Vector2(0.72, 0.72)
	tw.tween_property(score_label, "scale", Vector2(1.16, 1.16), 0.1).set_trans(Tween.TRANS_BACK)
	tw.tween_property(score_label, "scale", Vector2.ONE, 0.16)


func _celebrate() -> void:
	if celebrating:
		return
	celebrating = true
	AudioFx.play("cheer")
	replay_button.visible = true
	home_button.visible = true
	var copy: Array = balloons.duplicate()
	for i in copy.size():
		_pop_later(copy[i], i % 2, 0.06 * float(i))


func _pop_later(balloon: Node2D, player: int, delay: float) -> void:
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		if is_instance_valid(balloon) and not balloon.popping:
			_pop(balloon, player, false)
	)


func _click_at(pos: Vector2) -> void:
	if not celebrating:
		return
	if pos.distance_to(replay_button.global_position) < 80.0:
		_replay()
	elif pos.distance_to(home_button.global_position) < 80.0:
		_home()


func _button_fallback(player: int) -> Vector2:
	return replay_button.global_position if player == 0 else home_button.global_position


func _replay() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().reload_current_scene()


func _home() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if not celebrating:
		return
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_click_at((event as InputEventMouseButton).position)
	elif event.is_action_pressed("ui_cancel"):
		_home()
	elif event.is_action_pressed("ui_accept"):
		_replay()
	elif event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B:
		_home()


func debug_place_in_front(player: int) -> void:
	var dir := _aim_dir(player, Vector2.UP)
	var at: Vector2 = (bats[player] as Node2D).global_position + dir * 230.0
	_spawn_balloon(world.to_local(at), 60.0, Draw.BALLOON_COLORS[player])


func debug_balloon_count() -> int:
	return balloons.size()


class PartySky extends Node2D:
	const Draw := preload("res://scripts/party_draw.gd")
	var host

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var sun := 1.0 - clampf(host.time_left / host.ROUND, 0.0, 1.0)
		Draw.draw_sky(self, host._size(), host.elapsed, sun)


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
		Draw.draw_pips(self, Vector2(size.x * 0.5 - 117.0, 112.0), 10, filled, Draw.GOLD)


class EndCard extends Node2D:
	const Draw := preload("res://scripts/party_draw.gd")
	var host

	func _process(_delta: float) -> void:
		if host.celebrating:
			queue_redraw()

	func _draw() -> void:
		if not host.celebrating:
			return
		Draw.draw_end_card(self, host._size(), "Yay!", str(host.score))


class Bat extends Node2D:
	const Draw := preload("res://scripts/party_draw.gd")
	var player := 0
	var color := Color.WHITE
	var rest := 0.0
	var phase := 0.0
	var wobble := true

	func _process(delta: float) -> void:
		phase += delta
		if wobble:
			rotation = rest + sin(phase * 2.3 + float(player)) * 0.08
		queue_redraw()

	func _draw() -> void:
		Draw.draw_bat(self, color)


class Balloon extends Node2D:
	const Draw := preload("res://scripts/party_draw.gd")
	var radius := 64.0
	var color := Color.WHITE
	var vy := 80.0
	var vx := 0.0
	var phase := 0.0
	var popping := false

	func _draw() -> void:
		Draw.draw_balloon(self, radius, color)


class Swoosh extends Node2D:
	var dir := Vector2.UP
	var color := Color.WHITE
	var length := 520.0
	var width := 160.0
	var life := 0.0

	func _process(delta: float) -> void:
		life += delta
		if life > 0.34:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := clampf(life / 0.34, 0.0, 1.0)
		var grow := sin(t * PI)
		var base := dir.angle()
		var fade := 0.95 * grow
		draw_arc(Vector2.ZERO, length * 0.42, base - 1.15, base + 0.35, 18, Color(1, 1, 1, fade), 26.0, true)
		draw_arc(Vector2.ZERO, length * 0.68, base - 0.95, base + 0.2, 20, Color(color.r, color.g, color.b, fade), 18.0, true)
		draw_arc(Vector2.ZERO, length * 0.9, base - 0.7, base + 0.05, 16, Color(1, 1, 1, fade * 0.85), 10.0, true)


class Ring extends Node2D:
	var life := 0.0

	func _process(delta: float) -> void:
		life += delta
		if life > 0.32:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := life / 0.32
		draw_arc(Vector2.ZERO, lerpf(16.0, 92.0, t), 0, TAU, 32, Color(1, 1, 1, 1.0 - t), 8.0, true)


class Bit extends Node2D:
	var vel := Vector2.ZERO
	var spin := 0.0
	var color := Color.WHITE
	var life := 0.0
	var box := Vector2(10, 16)

	func _process(delta: float) -> void:
		life += delta
		vel.y += 1050.0 * delta
		position += vel * delta
		rotation += spin * delta
		modulate.a = clampf(1.0 - maxf(life - 0.5, 0.0) / 0.55, 0.0, 1.0)
		if life > 1.15:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-box * 0.5, box), color)


class Floater extends Node2D:
	const Draw := preload("res://scripts/party_draw.gd")
	var text := "+1"
	var life := 0.0
	var fill := Color.WHITE

	func _process(delta: float) -> void:
		life += delta
		position.y -= 130.0 * delta
		var s := 1.0
		if life < 0.16:
			s = lerpf(0.25, 1.32, life / 0.16)
		elif life < 0.32:
			s = lerpf(1.32, 1.0, (life - 0.16) / 0.16)
		scale = Vector2.ONE * s
		modulate.a = clampf(1.0 - maxf(life - 0.42, 0.0) / 0.35, 0.0, 1.0)
		if life > 0.82:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var pill := Rect2(-50, -30, 100, 58)
		Draw.draw_round_rect(self, pill.grow(6.0), 24.0, Draw.INK)
		Draw.draw_round_rect(self, pill, 20.0, Color("#fff8ea"))
		Draw.draw_text(self, Vector2(0, 2), text, 40, fill)
