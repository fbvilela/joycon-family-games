extends Node2D

const Draw := preload("res://scripts/party_draw.gd")

var cards: Array[Node2D] = []
var index := 0
var _nav_held := false
var _leaving := false


func _ready() -> void:
	var backdrop := Backdrop.new()
	backdrop.host = self
	backdrop.z_index = 0
	add_child(backdrop)
	var specs := [
		{"kind": "balloon", "title": "Bop", "name": "card_balloon"},
		{"kind": "tree", "title": "Shake", "name": "card_tree"},
		{"kind": "wheel", "title": "Drive", "name": "card_wheel"},
	]
	for spec in specs:
		var card := Card.new()
		card.kind = spec["kind"]
		card.title = spec["title"]
		card.name = spec["name"]
		card.phase = cards.size() * 0.6
		add_child(card)
		cards.append(card)
	_select(0)
	_layout()


func _size() -> Vector2:
	var size := get_viewport_rect().size
	if size.x < 32.0:
		return Vector2(1280, 720)
	return size


func _process(_delta: float) -> void:
	var size := _size()
	if cards.is_empty():
		return
	if cards[0].position == Vector2.ZERO:
		_layout()
	if absf(cards[0].get_meta("laid_w", 0.0) - size.x) > 1.0:
		_layout()


func _layout() -> void:
	var size := _size()
	var wide := size.x >= 980.0
	if wide:
		var gap := 40.0
		var w := 280.0
		var total := w * 3.0 + gap * 2.0
		var x0 := size.x * 0.5 - total * 0.5 + w * 0.5
		for i in cards.size():
			cards[i].position = Vector2(x0 + float(i) * (w + gap), size.y * 0.58)
			cards[i].set_meta("laid_w", size.x)
	else:
		for i in cards.size():
			cards[i].position = Vector2(size.x * 0.5, 250.0 + float(i) * 210.0)
			cards[i].set_meta("laid_w", size.x)


func _select(next: int) -> void:
	index = posmod(next, cards.size())
	for i in cards.size():
		cards[i].selected = i == index


func _start(kind: String) -> void:
	if _leaving:
		return
	_leaving = true
	AudioFx.play("ding")
	var path := "res://scenes/balloon_bop.tscn"
	if kind == "tree":
		path = "res://scenes/shake_tree.tscn"
	elif kind == "wheel":
		path = "res://scenes/wobbly_wheel.tscn"
	get_tree().change_scene_to_file(path)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right"):
		_select(index + 1)
	elif event.is_action_pressed("ui_left"):
		_select(index - 1)
	elif event.is_action_pressed("ui_accept"):
		_start(cards[index].kind)
	elif event is InputEventJoypadMotion and (event as InputEventJoypadMotion).axis == JOY_AXIS_LEFT_X:
		var axis := (event as InputEventJoypadMotion).axis_value
		if axis > 0.55 and not _nav_held:
			_nav_held = true
			_select(index + 1)
		elif axis < -0.55 and not _nav_held:
			_nav_held = true
			_select(index - 1)
		elif absf(axis) < 0.3:
			_nav_held = false
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var at := (event as InputEventMouseButton).position
		for card in cards:
			var rect := Rect2(card.global_position - card.size * 0.5, card.size)
			if rect.has_point(at):
				_start(card.kind)
				return
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_1:
				_start("balloon")
			KEY_2:
				_start("tree")
			KEY_3:
				_start("wheel")


class Backdrop extends Node2D:
	const Draw := preload("res://scripts/party_draw.gd")
	var host
	var time := 0.0

	func _process(delta: float) -> void:
		time += delta
		queue_redraw()

	func _draw() -> void:
		var size: Vector2 = host._size()
		Draw.draw_sky(self, size, time, 0.16)
		Draw.draw_text(self, Vector2(size.x * 0.5, 62), "Wiggle Party", 70, Color.WHITE)
		var pill := Rect2(size.x * 0.5 - 138.0, 112.0, 276.0, 46.0)
		Draw.draw_round_rect(self, pill, 23.0, Color(1, 1, 1, 0.82))
		Draw.draw_text(self, Vector2(size.x * 0.5, 135), "Pick a picture", 28, Draw.INK)
		var y := size.y - 42.0
		_dot(Vector2(size.x * 0.5 - 30.0, y), Draw.CORAL, MotionInput.sensor_enabled[0])
		_dot(Vector2(size.x * 0.5 + 30.0, y), Draw.GOLD, MotionInput.sensor_enabled[1])

	func _dot(at: Vector2, color: Color, sensor: bool) -> void:
		draw_circle(at, 16, color)
		draw_arc(at, 16, 0, TAU, 18, Draw.INK, 4.0, true)
		if sensor:
			draw_circle(at, 6, Color.WHITE)


class Card extends Node2D:
	const Draw := preload("res://scripts/party_draw.gd")
	var kind := "balloon"
	var title := "Bop"
	var selected := false
	var phase := 0.0
	var size := Vector2(280, 350)

	func _process(delta: float) -> void:
		phase += delta
		var s := 1.0 + sin(phase * 2.3) * 0.018
		if selected:
			s += 0.055
		scale = Vector2.ONE * s
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(-size.x * 0.5, -size.y * 0.5, size.x, size.y)
		draw_round_shadow(rect)
		Draw.draw_round_rect_outlined(self, rect, 30.0, Draw.CREAM, 9.0 if selected else 6.0)
		if selected:
			draw_arc(Vector2(0, -size.y * 0.5 + 28), 10, 0, TAU, 16, Draw.CORAL, 4.0, true)
		if kind == "balloon":
			_balloons()
		elif kind == "tree":
			_tree()
		else:
			_car()
		Draw.draw_text(self, Vector2(0, size.y * 0.36), title, 42, Draw.INK)

	func draw_round_shadow(rect: Rect2) -> void:
		Draw.draw_round_rect(self, Rect2(rect.position + Vector2(0, 12), rect.size), 30.0, Color(0.1, 0.14, 0.25, 0.16))

	func _balloons() -> void:
		draw_set_transform(Vector2(-48, -10), -0.08, Vector2.ONE)
		Draw.draw_balloon(self, 40, Draw.CORAL)
		draw_set_transform(Vector2(46, -36), 0.12, Vector2.ONE)
		Draw.draw_balloon(self, 32, Draw.GOLD)
		draw_set_transform(Vector2(2, 18), 0.0, Vector2.ONE)
		Draw.draw_balloon(self, 28, Draw.SKY)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _tree() -> void:
		draw_set_transform(Vector2(0, 86), 0.0, Vector2(0.52, 0.52))
		Draw.draw_tree(self, 1.0)
		draw_set_transform(Vector2(-58, 48), -0.35, Vector2.ONE)
		Draw.draw_apple(self, 20, Color("#ff4d4d"))
		draw_set_transform(Vector2(62, 36), 0.4, Vector2.ONE)
		Draw.draw_apple(self, 18, Color("#ff4d4d"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _car() -> void:
		draw_set_transform(Vector2(0, 10), -0.35, Vector2(1.15, 1.15))
		Draw.draw_car(self, Draw.CORAL)
		draw_set_transform(Vector2(-70, -40), 0.2, Vector2.ONE)
		Draw.draw_star(self, 22, Draw.GOLD)
		draw_set_transform(Vector2(72, -8), -0.2, Vector2.ONE)
		Draw.draw_star(self, 16, Draw.GOLD)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
