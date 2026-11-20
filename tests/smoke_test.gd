extends Node

var failures: Array[String] = []


func _ready() -> void:
	_run()


func _run() -> void:
	await get_tree().process_frame
	_test_api()
	await _test_backends()
	await _test_menu()
	await _test_balloon()
	await _test_tree()
	await _test_wheel()
	if failures.is_empty():
		print("SMOKE PASS")
		get_tree().quit(0)
	else:
		print("SMOKE FAIL %d" % failures.size())
		for item in failures:
			print(" - ", item)
		get_tree().quit(1)


func check(ok: bool, message: String) -> void:
	if ok:
		print("  ok   ", message)
	else:
		print("  FAIL ", message)
		failures.append(message)


func _test_api() -> void:
	print("API")
	var report: Dictionary = MotionInput.api_report()
	print(JSON.stringify(report))
	var info := Engine.get_version_info()
	check(int(info.major) == 4 and int(info.minor) >= 7, "Godot is 4.7 or newer")
	var methods: Dictionary = report["methods"]
	for key in methods.keys():
		check(bool(methods[key]), "Input.%s exists" % key)


func _test_backends() -> void:
	print("BACKENDS")
	var swings: Array = []
	var shakes: Array = []
	var taps: Array = []
	MotionInput.swing.connect(func(player: int, strength: float, direction: Vector2) -> void:
		swings.append(player)
	)
	MotionInput.shake.connect(func(player: int, intensity: float) -> void:
		shakes.append(player)
	)
	MotionInput.point_tap.connect(func(player: int, _aim: Vector2, _screen: Vector2) -> void:
		taps.append(player)
	)
	MotionInput.debug_reset()
	MotionInput.debug_feed_gyro(0, Vector3(0, 0, 6.5), 0.016)
	check(swings.size() >= 1 and swings[-1] == 0, "gyro spike emits a swing")
	MotionInput.debug_reset()
	swings.clear()
	MotionInput.debug_feed_mouse_velocity(0, Vector2(1500, -240))
	check(not swings.is_empty(), "fast mouse flick emits a swing")
	MotionInput.debug_reset()
	shakes.clear()
	MotionInput.debug_feed_mouse_velocity(0, Vector2(900, 40))
	MotionInput.debug_feed_mouse_velocity(0, Vector2(-900, -20))
	MotionInput.debug_feed_mouse_velocity(0, Vector2(880, 10))
	MotionInput.debug_feed_mouse_velocity(0, Vector2(-860, 0))
	check(not shakes.is_empty(), "mouse waggle emits a shake")
	MotionInput.debug_reset()
	swings.clear()
	MotionInput.debug_feed_stick(0, Vector2.ZERO, 0.016)
	MotionInput.debug_feed_stick(0, Vector2(0.96, -0.2), 0.016)
	check(not swings.is_empty(), "stick flick emits a swing")
	check(MotionInput.tilt[0].length() > 0.5, "stick sets tilt")
	MotionInput.debug_reset()
	shakes.clear()
	MotionInput.debug_feed_stick(1, Vector2(0.85, 0), 0.05)
	MotionInput.debug_feed_stick(1, Vector2(-0.85, 0), 0.05)
	MotionInput.debug_feed_stick(1, Vector2(0.85, 0), 0.05)
	MotionInput.debug_feed_stick(1, Vector2(-0.85, 0), 0.05)
	check(shakes.has(1), "stick waggle emits a shake for player 2")
	MotionInput.debug_reset()
	MotionInput.debug_feed_gravity(0, Vector3(4.2, -8.0, -1.2))
	check(MotionInput.tilt[0].x > 0.8, "gravity rolls into tilt")
	MotionInput.debug_reset()
	taps.clear()
	swings.clear()
	MotionInput.debug_press_button(1)
	check(swings.has(1) and taps.has(1), "button is a swing and a point tap")
	MotionInput.debug_reset()
	var before := swings.size()
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(420, 280)
	motion.relative = Vector2(36, -12)
	motion.velocity = Vector2(1600, -280)
	Input.parse_input_event(motion)
	await get_tree().process_frame
	await get_tree().process_frame
	check(swings.size() > before, "parsed mouse motion reaches MotionInput")
	MotionInput.debug_reset()


func _test_menu() -> void:
	print("MENU")
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	check(menu.get_node_or_null("card_balloon") != null, "menu has balloon card")
	check(menu.get_node_or_null("card_tree") != null, "menu has tree card")
	check(menu.get_node_or_null("card_wheel") != null, "menu has wheel card")
	menu.queue_free()
	await get_tree().process_frame


func _test_balloon() -> void:
	print("BALLOON")
	var game := (load("res://scenes/balloon_bop.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	check(game.get_script() != null, "balloon script loaded")
	if game.get_script() == null:
		game.queue_free()
		await get_tree().process_frame
		return
	check(game.debug_balloon_count() >= 6, "balloon round starts full of balloons")
	var before: int = game.score
	game.debug_place_in_front(0)
	MotionInput.inject_swing(0, 1.0, Vector2.UP)
	await get_tree().process_frame
	check(game.score > before, "a swing pops a balloon and scores")
	game.debug_place_in_front(1)
	var mid: int = game.score
	MotionInput.inject_swing(1, 1.0, Vector2.UP)
	await get_tree().process_frame
	check(game.score > mid, "the second player can score too")
	game.queue_free()
	await get_tree().process_frame


func _test_tree() -> void:
	print("TREE")
	var game := (load("res://scenes/shake_tree.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	check(game.get_script() != null, "tree script loaded")
	if game.get_script() == null:
		game.queue_free()
		await get_tree().process_frame
		return
	MotionInput.inject_shake(0, 1.0)
	check(game.debug_loose() >= 2, "a shake knocks apples loose")
	await get_tree().create_timer(1.4).timeout
	check(game.caught >= 1, "apples land in the basket")
	game.queue_free()
	await get_tree().process_frame


func _test_wheel() -> void:
	print("WHEEL")
	var game := (load("res://scenes/wobbly_wheel.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	var start: float = game.debug_car_x()
	MotionInput.debug_reset()
	MotionInput.inject_tilt(0, Vector2(1, 0))
	await get_tree().create_timer(0.55).timeout
	check(game.debug_car_x() > start + 30.0, "tilt steers the car to the right")
	game.queue_free()
	await get_tree().process_frame
