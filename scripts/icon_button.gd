extends Node2D

const Draw := preload("res://scripts/party_draw.gd")

var kind := "replay"
var fill := Color("#7d8cff")
var phase := 0.0


func _process(delta: float) -> void:
	phase += delta
	scale = Vector2.ONE * (1.0 + sin(phase * 3.2) * 0.045)
	queue_redraw()


func _draw() -> void:
	Draw.draw_button(self, 62.0, fill)
	if kind == "replay":
		Draw.draw_replay(self, 62.0)
	else:
		Draw.draw_house(self, 32.0)
