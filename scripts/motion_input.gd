extends Node

## Shared motion input for two players (parent = 0, child = 1).
##
## Backends, in the order they are polled:
## 1. Joy-Con / gamepad. Godot 4.7+ can read joypad gyro and accelerometer.
##    Sensors are enabled when has_joy_motion_sensors() is true. A running
##    high-pass removes gyro bias so a 5-year-old does not have to lay the
##    controller on a table before playing.
## 2. Stick and face buttons. A quick stick flick is a swing, waggling the
##    stick is a shake, holding the stick is tilt and aim, any button is a
##    swing plus a point-tap.
## 3. Mouse and keyboard, used for a player who has no joypad (or for player 0
##    when JOY_PARTY_FORCE_MOUSE=1, the JoyShockMapper workaround).
##
## Thresholds are intentionally low. A small wrist flick should count.

signal swing(player: int, strength: float, direction: Vector2)
signal shake(player: int, intensity: float)
signal tilt_changed(player: int, tilt: Vector2)
signal point_changed(player: int, aim: Vector2, screen_pos: Vector2)
signal point_tap(player: int, aim: Vector2, screen_pos: Vector2)

const PLAYERS := 2
const GYRO_SWING := 1.7
const GYRO_SHAKE := 2.2
const STICK_DEAD := 0.2
const STICK_FLICK := 7.5
const MOUSE_SWING := 700.0
const MOUSE_SHAKE := 480.0
const GRAVITY_FULL_TILT := 4.2

const ACTION_BUTTONS: Array[JoyButton] = [
	JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y,
	JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER,
	JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK,
	JOY_BUTTON_PADDLE1, JOY_BUTTON_PADDLE2, JOY_BUTTON_PADDLE3, JOY_BUTTON_PADDLE4,
	JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT,
]

var swing_strength: Array[float] = [0.0, 0.0]
var swing_direction: Array[Vector2] = [Vector2.UP, Vector2.UP]
var shake_intensity: Array[float] = [0.0, 0.0]
var tilt: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var point_aim: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var point_screen: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var sensor_enabled: Array[bool] = [false, false]
var last_backend: Array[String] = ["none", "none"]
var demo := false
var force_mouse := false

var _joy_api := false
var _swing_cd: Array[float] = [0.0, 0.0]
var _shake_cd: Array[float] = [0.0, 0.0]
var _shake_meter: Array[float] = [0.0, 0.0]
var _last_shake_sign: Array[int] = [0, 0]
var _stick: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _button_held: Array[bool] = [false, false]
var _trigger_held: Array[bool] = [false, false]
var _tilt_source: Array[String] = ["none", "none"]
var _gyro_bias: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _prev_accel: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _calib_left := {}
var _api := {}


func _ready() -> void:
	process_priority = -100
	demo = OS.get_cmdline_user_args().has("demo") or OS.get_environment("JOY_PARTY_DEMO") == "1"
	force_mouse = OS.get_environment("JOY_PARTY_FORCE_MOUSE") == "1"
	_joy_api = (
		Input.has_method("get_joy_gyroscope")
		and Input.has_method("get_joy_accelerometer")
		and Input.has_method("get_joy_gravity")
		and Input.has_method("has_joy_motion_sensors")
		and Input.has_method("set_joy_motion_sensors_enabled")
	)
	_api = api_report()
	print("MotionInput ready | %s" % JSON.stringify(_api))
	if not Input.joy_connection_changed.is_connected(_on_joy_connection):
		Input.joy_connection_changed.connect(_on_joy_connection)
	for device in Input.get_connected_joypads():
		_enable_sensors(int(device))


func api_report() -> Dictionary:
	var info := Engine.get_version_info()
	return {
		"godot": "%s.%s.%s-%s" % [info.major, info.minor, info.patch, info.status],
		"godot_hash": str(info.hash),
		"joy_motion_api": _joy_api if is_inside_tree() else Input.has_method("get_joy_gyroscope"),
		"methods": {
			"get_joy_gyroscope": Input.has_method("get_joy_gyroscope"),
			"get_joy_accelerometer": Input.has_method("get_joy_accelerometer"),
			"get_joy_gravity": Input.has_method("get_joy_gravity"),
			"has_joy_motion_sensors": Input.has_method("has_joy_motion_sensors"),
			"set_joy_motion_sensors_enabled": Input.has_method("set_joy_motion_sensors_enabled"),
			"start_joy_motion_sensors_calibration": Input.has_method("start_joy_motion_sensors_calibration"),
			"is_joy_motion_sensors_calibrated": Input.has_method("is_joy_motion_sensors_calibrated"),
		},
		"device_gyroscope": "Input.get_gyroscope() is the phone sensor. It returns zero on macOS, Windows and Linux.",
		"demo": demo,
		"force_mouse": force_mouse,
	}


func _process(delta: float) -> void:
	_decay(delta)
	_finish_calibration(delta)
	_poll_joypads(delta)
	_poll_keyboard()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _pointer_enabled(0):
		var motion := event as InputEventMouseMotion
		_set_point(0, _screen_to_aim(motion.position), motion.position, "mouse")
		_consume_pointer_velocity(0, motion.velocity)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _pointer_enabled(0):
		var click := event as InputEventMouseButton
		_set_point(0, _screen_to_aim(click.position), click.position, "mouse")
		_emit_swing(0, 0.8, _fallback_dir(0), "mouse_click")
		_emit_tap(0, "mouse_click")
	elif event is InputEventKey and event.pressed and not event.echo:
		_on_key((event as InputEventKey).physical_keycode)


func inject_swing(player: int, strength: float, direction: Vector2) -> void:
	_emit_swing(player, strength, direction, "inject", true)


func inject_shake(player: int, intensity: float) -> void:
	_emit_shake(player, intensity, "inject", true)


func inject_tilt(player: int, value: Vector2) -> void:
	_set_tilt(player, value, "inject")


func inject_point(player: int, aim: Vector2, screen_pos: Vector2) -> void:
	_set_point(player, aim, screen_pos, "inject")
	point_changed.emit(player, point_aim[player], point_screen[player])


func inject_tap(player: int) -> void:
	_emit_tap(player, "inject")


func debug_feed_stick(player: int, stick: Vector2, delta: float) -> void:
	_consume_stick(player, stick, delta)


func debug_feed_gyro(player: int, gyro: Vector3, delta: float) -> void:
	_consume_gyro(player, gyro, delta)


func debug_feed_accel(player: int, accel: Vector3, delta: float) -> void:
	_consume_accel(player, accel, delta)


func debug_feed_gravity(player: int, gravity: Vector3) -> void:
	_consume_gravity(player, gravity)


func debug_feed_mouse_velocity(player: int, velocity: Vector2) -> void:
	_consume_pointer_velocity(player, velocity)


func debug_press_button(player: int) -> void:
	_consume_button(player)


func debug_reset() -> void:
	for i in PLAYERS:
		_swing_cd[i] = 0.0
		_shake_cd[i] = 0.0
		_shake_meter[i] = 0.0
		_last_shake_sign[i] = 0
		_gyro_bias[i] = Vector3.ZERO
		_prev_accel[i] = Vector3.ZERO
		_stick[i] = Vector2.ZERO
		_button_held[i] = false
		_trigger_held[i] = false
		_tilt_source[i] = "none"
		tilt[i] = Vector2.ZERO
		swing_strength[i] = 0.0
		shake_intensity[i] = 0.0


func _on_joy_connection(device: int, connected: bool) -> void:
	print("MotionInput joypad %d connected=%s name=%s" % [device, connected, Input.get_joy_name(device) if connected else ""])
	if connected:
		_enable_sensors(device)
	else:
		var player := _player_for_device(device)
		if player >= 0:
			sensor_enabled[player] = false


func _enable_sensors(device: int) -> void:
	var player := _player_for_device(device)
	if player < 0 or not _joy_api:
		print("MotionInput joypad %d '%s' (no player slot or no joy motion API)" % [device, Input.get_joy_name(device)])
		return
	var has := bool(Input.has_joy_motion_sensors(device))
	sensor_enabled[player] = has
	if not has:
		print("MotionInput joypad %d '%s' has no motion sensors. Stick and buttons will drive player %d." % [device, Input.get_joy_name(device), player])
		return
	Input.set_joy_motion_sensors_enabled(device, true)
	print("MotionInput joypad %d '%s' motion sensors ON for player %d." % [device, Input.get_joy_name(device), player])


func _finish_calibration(delta: float) -> void:
	for device in _calib_left.keys():
		_calib_left[device] = float(_calib_left[device]) - delta
		if float(_calib_left[device]) <= 0.0:
			if _joy_api and Input.has_method("stop_joy_motion_sensors_calibration"):
				Input.stop_joy_motion_sensors_calibration(int(device))
			_calib_left.erase(device)
			print("MotionInput calibration finished for joypad %s" % str(device))


func calibrate_all() -> void:
	if not _joy_api or not Input.has_method("start_joy_motion_sensors_calibration"):
		print("MotionInput calibration API is not in this Godot build.")
		return
	for device in Input.get_connected_joypads():
		if Input.has_joy_motion_sensors(int(device)):
			Input.start_joy_motion_sensors_calibration(int(device))
			_calib_left[device] = 1.0
	for i in PLAYERS:
		_gyro_bias[i] = Vector3.ZERO
	print("MotionInput: hold the Joy-Cons still for a second.")


func _decay(delta: float) -> void:
	for i in PLAYERS:
		_swing_cd[i] = maxf(_swing_cd[i] - delta, 0.0)
		_shake_cd[i] = maxf(_shake_cd[i] - delta, 0.0)
		_shake_meter[i] = maxf(_shake_meter[i] - delta * 2.4, 0.0)
		swing_strength[i] = move_toward(swing_strength[i], 0.0, delta * 1.8)
		shake_intensity[i] = move_toward(shake_intensity[i], 0.0, delta * 1.6)


func _poll_joypads(delta: float) -> void:
	for device in Input.get_connected_joypads():
		var player := _player_for_device(int(device))
		if player < 0:
			continue
		var stick := Vector2(
			Input.get_joy_axis(int(device), JOY_AXIS_LEFT_X),
			Input.get_joy_axis(int(device), JOY_AXIS_LEFT_Y)
		)
		if stick.length() < STICK_DEAD:
			stick = Vector2.ZERO
		else:
			stick = stick.limit_length(1.0)
		_consume_stick(player, stick, delta)
		var right := Vector2(
			Input.get_joy_axis(int(device), JOY_AXIS_RIGHT_X),
			Input.get_joy_axis(int(device), JOY_AXIS_RIGHT_Y)
		)
		if right.length() > STICK_DEAD:
			_set_point(player, right.limit_length(1.0), _aim_to_screen(right), "joy_stick")
		var held := false
		for button in ACTION_BUTTONS:
			if Input.is_joy_button_pressed(int(device), button):
				held = true
				break
		if held and not _button_held[player]:
			_consume_button(player)
		_button_held[player] = held
		var trigger := (
			Input.get_joy_axis(int(device), JOY_AXIS_TRIGGER_LEFT) > 0.55
			or Input.get_joy_axis(int(device), JOY_AXIS_TRIGGER_RIGHT) > 0.55
		)
		if trigger and not _trigger_held[player]:
			_consume_button(player)
		_trigger_held[player] = trigger
		if _joy_api and Input.is_joy_motion_sensors_enabled(int(device)):
			_consume_gyro(player, Input.get_joy_gyroscope(int(device)), delta)
			_consume_accel(player, Input.get_joy_accelerometer(int(device)), delta)
			_consume_gravity(player, Input.get_joy_gravity(int(device)))


func _poll_keyboard() -> void:
	if _pointer_enabled(0):
		var parent := _keys(KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN)
		if parent != Vector2.ZERO:
			_set_tilt(0, parent, "keys")
		elif _tilt_source[0] == "keys":
			_set_tilt(0, Vector2.ZERO, "keys")
	if _pointer_enabled(1):
		var child := _keys(KEY_A, KEY_D, KEY_W, KEY_S)
		if child != Vector2.ZERO:
			_set_tilt(1, child, "keys")
		elif _tilt_source[1] == "keys":
			_set_tilt(1, Vector2.ZERO, "keys")


func _on_key(key: Key) -> void:
	if key == KEY_C:
		calibrate_all()
		return
	if _pointer_enabled(0) and (key == KEY_SPACE or key == KEY_R):
		if key == KEY_SPACE:
			_emit_swing(0, 0.9, _fallback_dir(0), "key")
			_emit_tap(0, "key")
		else:
			_emit_shake(0, 1.0, "key", true)
	if _pointer_enabled(1) and (key == KEY_F or key == KEY_T or key == KEY_G):
		if key == KEY_F:
			_emit_swing(1, 0.9, _fallback_dir(1), "key")
			_emit_tap(1, "key")
		elif key == KEY_T:
			_emit_shake(1, 1.0, "key", true)
		else:
			_emit_tap(1, "key")


func _consume_stick(player: int, stick: Vector2, delta: float) -> void:
	var prev := _stick[player]
	_stick[player] = stick
	if _tilt_source[player] != "gravity":
		_set_tilt(player, stick, "stick")
	_set_point(player, stick, _aim_to_screen(stick), "stick")
	var vel := (stick - prev) / maxf(delta, 0.001)
	if vel.length() > STICK_FLICK and stick.length() > 0.4:
		_emit_swing(player, clampf(vel.length() / 14.0, 0.55, 1.0), vel.normalized(), "stick")
	if absf(stick.x) > 0.38:
		var sign_x := 1 if stick.x > 0.0 else -1
		if sign_x != _last_shake_sign[player] and _last_shake_sign[player] != 0:
			_bump_shake_meter(player)
		_last_shake_sign[player] = sign_x


func _consume_button(player: int) -> void:
	_emit_swing(player, 0.88, _fallback_dir(player), "button")
	_emit_tap(player, "button")


func _consume_gyro(player: int, raw: Vector3, delta: float) -> void:
	var follow := clampf(delta * 1.15, 0.0, 0.05)
	_gyro_bias[player] = _gyro_bias[player].lerp(raw, follow)
	var corrected := raw - _gyro_bias[player]
	var mag := corrected.length()
	if mag > GYRO_SWING:
		var dir := Vector2(corrected.z, -corrected.x)
		if dir.length() < 0.15:
			dir = Vector2(corrected.y, -corrected.x)
		if dir.length() < 0.05:
			dir = Vector2.UP
		_emit_swing(player, clampf(mag / 6.0, 0.5, 1.0), dir.normalized(), "gyro")
	if mag > GYRO_SHAKE:
		var axis := corrected.x
		if absf(corrected.y) > absf(axis):
			axis = corrected.y
		if absf(corrected.z) > absf(axis):
			axis = corrected.z
		var sign_g := 1 if axis >= 0.0 else -1
		if sign_g != _last_shake_sign[player] and _last_shake_sign[player] != 0:
			_bump_shake_meter(player)
		_last_shake_sign[player] = sign_g


func _consume_accel(player: int, accel: Vector3, delta: float) -> void:
	var prev := _prev_accel[player]
	_prev_accel[player] = accel
	if prev.length() < 0.01 and accel.length() < 0.01:
		return
	var jerk := (accel - prev).length() / maxf(delta, 0.001)
	if jerk > 70.0:
		_bump_shake_meter(player)


func _consume_gravity(player: int, gravity: Vector3) -> void:
	if gravity.length() < 3.0:
		if _tilt_source[player] == "gravity":
			_tilt_source[player] = "none"
		return
	var value := Vector2(gravity.x, gravity.z) / GRAVITY_FULL_TILT
	_set_tilt(player, Vector2(clampf(value.x, -1.0, 1.0), clampf(value.y, -1.0, 1.0)), "gravity")


func _consume_pointer_velocity(player: int, velocity: Vector2) -> void:
	var speed := velocity.length()
	if speed >= MOUSE_SWING:
		_emit_swing(player, clampf(speed / 1600.0, 0.55, 1.0), velocity.normalized(), "mouse")
	if speed >= MOUSE_SHAKE:
		var axis := velocity.x if absf(velocity.x) >= absf(velocity.y) else velocity.y
		var sign_m := 1 if axis >= 0.0 else -1
		if sign_m != _last_shake_sign[player] and _last_shake_sign[player] != 0:
			_bump_shake_meter(player)
		_last_shake_sign[player] = sign_m


func _bump_shake_meter(player: int) -> void:
	_shake_meter[player] += 1.0
	if _shake_meter[player] >= 3.0:
		_emit_shake(player, clampf(_shake_meter[player] / 4.0, 0.7, 1.0), "motion")
		_shake_meter[player] = 0.0


func _emit_swing(player: int, strength: float, direction: Vector2, backend: String, force := false) -> void:
	if player < 0 or player >= PLAYERS:
		return
	if not force and _swing_cd[player] > 0.0:
		return
	if not force:
		_swing_cd[player] = 0.18
	var dir := direction.normalized() if direction.length() > 0.01 else _fallback_dir(player)
	swing_strength[player] = clampf(strength, 0.0, 1.5)
	swing_direction[player] = dir
	last_backend[player] = backend
	swing.emit(player, swing_strength[player], dir)


func _emit_shake(player: int, intensity: float, backend: String, force := false) -> void:
	if player < 0 or player >= PLAYERS:
		return
	if not force and _shake_cd[player] > 0.0:
		return
	if not force:
		_shake_cd[player] = 0.32
	shake_intensity[player] = clampf(intensity, 0.0, 1.5)
	last_backend[player] = backend
	shake.emit(player, shake_intensity[player])


func _emit_tap(player: int, backend: String) -> void:
	if player < 0 or player >= PLAYERS:
		return
	last_backend[player] = backend
	point_tap.emit(player, point_aim[player], point_screen[player])


func _set_tilt(player: int, value: Vector2, source: String) -> void:
	var next := Vector2(clampf(value.x, -1.0, 1.0), clampf(value.y, -1.0, 1.0))
	var changed := next.distance_to(tilt[player]) > 0.02 or source != _tilt_source[player]
	tilt[player] = next
	_tilt_source[player] = source
	if changed:
		tilt_changed.emit(player, next)


func _set_point(player: int, aim: Vector2, screen: Vector2, backend: String) -> void:
	var next := Vector2(clampf(aim.x, -1.0, 1.0), clampf(aim.y, -1.0, 1.0))
	var moved := next.distance_to(point_aim[player]) > 0.04 or screen.distance_to(point_screen[player]) > 6.0
	point_aim[player] = next
	point_screen[player] = screen
	last_backend[player] = backend
	if moved:
		point_changed.emit(player, next, screen)


func _fallback_dir(player: int) -> Vector2:
	if _stick[player].length() > 0.25:
		return _stick[player].normalized()
	return Vector2(-0.35, -1.0).normalized() if player == 0 else Vector2(0.35, -1.0).normalized()


func _player_for_device(device: int) -> int:
	var pads: Array = Input.get_connected_joypads()
	var idx := pads.find(device)
	if idx < 0 or idx >= PLAYERS:
		return -1
	return idx


func _pointer_enabled(player: int) -> bool:
	if force_mouse and player == 0:
		return true
	return Input.get_connected_joypads().size() <= player


func _keys(left: Key, right: Key, up: Key, down: Key) -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(left):
		v.x -= 1.0
	if Input.is_physical_key_pressed(right):
		v.x += 1.0
	if Input.is_physical_key_pressed(up):
		v.y -= 1.0
	if Input.is_physical_key_pressed(down):
		v.y += 1.0
	return v.limit_length(1.0)


func _viewport_size() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2(1280, 720)
	var size := viewport.get_visible_rect().size
	if size.x < 32.0 or size.y < 32.0:
		return Vector2(1280, 720)
	return size


func _aim_to_screen(aim: Vector2) -> Vector2:
	var size := _viewport_size()
	return size * 0.5 + Vector2(aim.x, aim.y) * size * 0.42


func _screen_to_aim(screen: Vector2) -> Vector2:
	var size := _viewport_size()
	return Vector2(screen.x / size.x * 2.0 - 1.0, screen.y / size.y * 2.0 - 1.0)
