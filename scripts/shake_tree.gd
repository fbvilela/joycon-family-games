extends Node2D

const Draw := preload("res://scripts/party_draw.gd")
const IconButton := preload("res://scripts/icon_button.gd")
const ROUND := 24.0
const TREE_SCALE := 1.15
const SPOTS: Array[Vector2] = [
	Vector2(-48, -150), Vector2(56, -142), Vector2(-86, -96), Vector2(96, -90),
	Vector2(0, -188), Vector2(-18, -112), Vector2(30, -206), Vector2(78, -168),
	Vector2(-70, -186), Vector2(8, -64), Vector2(-110, -62), Vector2(118, -52),
]

var caught := 0
var time_left := ROUND
var elapsed := 0.0
var celebrating := false
var world: Node2D
var tree: Node2D
var basket: Node2D
var effects: Node2D
var apples: Array = []
var score_label: Label
var replay_button: Node2D
var home_button: Node2D
var _shake_left := 0.0
var _demo_wait := 0.45
var _leaving := false
var _rain := 0.0


func _ready() -> void:
	if MotionInput.demo:
		seed(3)
	else:
		randomize()
	_build()
	MotionInput.shake.connect(_on_shake)
	MotionInput.swing.connect(_on_swing)
	MotionInput.point_tap.connect(_on_tap)


func _size() -> Vector2:
	var size := get_viewport_rect().size
	if size.x < 32.0:
		return Vector2(1280, 720)
	return size


func _build() -> void:
	var size := _size()
	world = Node2D.new()
	add_child(world)
	var sky := PartySky.new()
	sky.host = self
	world.add_child(sky)
	tree = Node2D.new()
	tree.position = Vector2(size.x * 0.5, size.y * 0.6)
	tree.z_index = 2
	world.add_child(tree)
	var art := TreeArt.new()
	art.scale_factor = TREE_SCALE
	tree.add_child(art)
	for spot in SPOTS:
		var apple := Apple.new()
		apple.position = spot * TREE_SCALE
		apple.z_index = 3
		tree.add_child(apple)
		apples.append(apple)
	basket = BasketDraw.new()
	basket.position = Vector2(size.x * 0.5, size.y * 0.86)
	basket.z_index = 4
	world.add_child(basket)
	effects = Node2D.new()
	effects.z_index = 6
	world.add_child(effects)
	var hud := CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	var pips := HudArt.new()
	pips.host = self
	hud.add_child(pips)
	score_label = _label(64)
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
	_layout_hud()
	_refresh()


func _label(size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Draw.INK)
	label.add_theme_constant_override("outline_size", 16)
	label.custom_minimum_size = Vector2(160, 84)
	label.pivot_offset = Vector2(80, 42)
	return label


func _layout_hud() -> void:
	var size := _size()
	score_label.position = Vector2(size.x * 0.5 - 80.0, 8.0)
	replay_button.position = Vector2(size.x * 0.38, size.y * 0.8)
	home_button.position = Vector2(size.x * 0.62, size.y * 0.8)
	basket.position = Vector2(size.x * 0.5, size.y * 0.86)
	tree.position = Vector2(size.x * 0.5, size.y * 0.6)


func _process(delta: float) -> void:
	elapsed += delta
	_shake_left = maxf(_shake_left - delta, 0.0)
	if not celebrating:
		time_left = maxf(time_left - delta, 0.0)
		_fall(delta)
		if MotionInput.demo:
			_demo_wait -= delta
			if _demo_wait <= 0.0:
				_demo_wait = 1.05
				MotionInput.inject_shake(0, 0.7)
		if time_left <= 0.0:
			_celebrate()
	else:
		_rain -= delta
		if _rain <= 0.0:
			_rain = 0.12
			_bits(Vector2(randf_range(40, _size().x - 40), -10), Draw.GOLD, 6)


func _fall(delta: float) -> void:
	var size := _size()
	var rim := basket.position.y - 24.0
	for apple in apples:
		if not apple.falling or apple.caught:
			continue
		apple.vel.y += 820.0 * delta
		apple.position += apple.vel * delta
		apple.rotation += delta * apple.vel.x * 0.01
		if apple.position.y >= rim and absf(apple.position.x - basket.position.x) < 280.0:
			var slot := caught
			apple.caught = true
			apple.falling = false
			apple.vel = Vector2.ZERO
			var col := slot % 6
			var row := int(float(slot) / 6.0)
			apple.position = basket.position + Vector2((float(col) - 2.5) * 44.0, 4.0 + float(row) * 8.0)
			apple.rotation = randf_range(-0.45, 0.45)
			apple.scale = Vector2.ONE * 1.25
			apple.z_index = 5
			caught += 1
			_refresh()
			_bump()
			AudioFx.play("ding")
			_bits(apple.position + Vector2(0, -36), Draw.GOLD, 4)
		elif apple.position.y > size.y * 0.95:
			apple.position.y = size.y * 0.95
			apple.vel = Vector2(signf(basket.position.x - apple.position.x) * 240.0, -160.0)


func _on_shake(player: int, intensity: float) -> void:
	if celebrating:
		return
	_wobble()
	var drops := 3 if intensity >= 0.75 else 2
	_release(drops)
	AudioFx.play("whoosh")
	_shake_left = 0.28


func _on_swing(_player: int, _strength: float, _direction: Vector2) -> void:
	if celebrating:
		return
	_wobble()
	_release(1)


func _on_tap(player: int, _aim: Vector2, screen_pos: Vector2) -> void:
	if celebrating:
		var at := screen_pos if screen_pos != Vector2.ZERO else replay_button.global_position
		if player == 1 and screen_pos == Vector2.ZERO:
			at = home_button.global_position
		_click_at(at)


func _release(count: int) -> void:
	var n := 0
	for apple in apples:
		if n >= count:
			break
		if apple.falling or apple.caught:
			continue
		var global_pos: Vector2 = tree.to_global(apple.position)
		apple.get_parent().remove_child(apple)
		world.add_child(apple)
		apple.global_position = global_pos
		apple.falling = true
		apple.vel = Vector2(randf_range(-170.0, 170.0), 30.0)
		apple.z_index = 8
		apple.scale = Vector2.ONE * 1.15
		n += 1
	if n > 0:
		AudioFx.play("thud")


func _wobble() -> void:
	var tw := create_tween()
	tw.tween_property(tree, "rotation", 0.16, 0.06)
	tw.tween_property(tree, "rotation", -0.14, 0.08)
	tw.tween_property(tree, "rotation", 0.08, 0.07)
	tw.tween_property(tree, "rotation", 0.0, 0.1).set_trans(Tween.TRANS_BACK)


func _bits(at: Vector2, color: Color, count: int) -> void:
	for _i in count:
		var bit := Bit.new()
		bit.position = at
		bit.color = color
		var ang := randf() * TAU
		bit.vel = Vector2(cos(ang), sin(ang)) * randf_range(120.0, 360.0)
		bit.spin = randf_range(-6.0, 6.0)
		effects.add_child(bit)


func _refresh() -> void:
	score_label.text = str(caught)


func _bump() -> void:
	var tw := create_tween()
	score_label.scale = Vector2(0.7, 0.7)
	tw.tween_property(score_label, "scale", Vector2(1.15, 1.15), 0.1).set_trans(Tween.TRANS_BACK)
	tw.tween_property(score_label, "scale", Vector2.ONE, 0.14)


func _celebrate() -> void:
	if celebrating:
		return
	celebrating = true
	AudioFx.play("cheer")
	replay_button.visible = true
	home_button.visible = true


func _click_at(pos: Vector2) -> void:
	if pos.distance_to(replay_button.global_position) < 80.0:
		_go("res://scenes/shake_tree.tscn")
	elif pos.distance_to(home_button.global_position) < 80.0:
		_go("res://scenes/main_menu.tscn")


func _go(path: String) -> void:
	if _leaving:
		return
	_leaving = true
	if path.ends_with("shake_tree.tscn"):
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(path)


func _unhandled_input(event: InputEvent) -> void:
	if not celebrating:
		return
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_click_at((event as InputEventMouseButton).position)
	elif event.is_action_pressed("ui_cancel"):
		_go("res://scenes/main_menu.tscn")
	elif event.is_action_pressed("ui_accept"):
		_go("res://scenes/shake_tree.tscn")


func debug_loose() -> int:
	var n := 0
	for apple in apples:
		if apple.falling or apple.caught:
			n += 1
	return n


class PartySky extends Node2D:
	const Draw := preload("res://scripts/party_draw.gd")
	var host

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var sun := 1.0 - clampf(host.time_left / host.ROUND, 0.0, 1.0)
		Draw.draw_sky(self, host._size(), host.elapsed, sun)
		if host._shake_left > 0.0:
			var tree_pos: Vector2 = host.tree.position
			draw_arc(tree_pos + Vector2(-150, -220), 40, 0.4, 2.2, 12, Draw.INK, 6.0, true)
			draw_arc(tree_pos + Vector2(160, -200), 34, PI + 0.4, PI + 2.0, 12, Draw.INK, 6.0, true)


class TreeArt extends Node2D:
	const Draw := preload("res://scripts/party_draw.gd")
	var scale_factor := 1.0

	func _draw() -> void:
		Draw.draw_tree(self, scale_factor)


class Apple extends Node2D:
	const Draw := preload("res://scripts/party_draw.gd")
	var falling := false
	var caught := false
	var vel := Vector2.ZERO

	func _draw() -> void:
		Draw.draw_apple(self, 22.0, Color("#ff4d4d"))


class BasketDraw extends Node2D:
	const Draw := preload("res://scripts/party_draw.gd")

	func _draw() -> void:
		Draw.draw_basket(self, 560.0, 110.0)


class HudArt extends Node2D:
	const Draw := preload("res://scripts/party_draw.gd")
	var host

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if host.celebrating:
			return
		var size: Vector2 = host._size()
		var filled := int(ceil(host.time_left / host.ROUND * 8.0))
		Draw.draw_pips(self, Vector2(size.x * 0.5 - 91.0, 100.0), 8, filled, Color("#ff4d4d"))


class EndCard extends Node2D:
	const Draw := preload("res://scripts/party_draw.gd")
	var host

	func _process(_delta: float) -> void:
		if host.celebrating:
			queue_redraw()

	func _draw() -> void:
		if not host.celebrating:
			return
		Draw.draw_end_card(self, host._size(), "Apples!", str(host.caught))


class Bit extends Node2D:
	var vel := Vector2.ZERO
	var spin := 0.0
	var color := Color.WHITE
	var life := 0.0

	func _process(delta: float) -> void:
		life += delta
		vel.y += 900.0 * delta
		position += vel * delta
		rotation += spin * delta
		if life > 0.8:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-5, -8, 10, 16), color)
