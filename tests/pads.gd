extends Node

## Prints every joypad Godot can see, then quits.
##
##   godot --path . --audio-driver Dummy res://tests/pads.tscn
##
## Exit code is always 0. PAD COUNT 0 means this process saw no pad.
## Player 0 is pads[0] (parent). Player 1 is pads[1] (child).


func _ready() -> void:
	await get_tree().process_frame
	var pads: Array = Input.get_connected_joypads()
	print("PAD COUNT %d" % pads.size())
	if pads.is_empty():
		print("PAD NONE")
		get_tree().quit(0)
		return
	for index in pads.size():
		var device := int(pads[index])
		var sensors := false
		if Input.has_method("has_joy_motion_sensors"):
			sensors = bool(Input.has_joy_motion_sensors(device))
		var role := "unused"
		if index == 0:
			role = "player0-parent"
		elif index == 1:
			role = "player1-child"
		print(
			"PAD %d device=%d role=%s sensors=%s name=%s guid=%s"
			% [index, device, role, str(sensors), Input.get_joy_name(device), Input.get_joy_guid(device)]
		)
	get_tree().quit(0)
