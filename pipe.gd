extends Node2D
var player
var width
# Called when the node enters the scene tree for the first time.
func _ready():
	player = get_tree().get_first_node_in_group("player")

func _on_top_pipe_body_entered(body):
	if body.is_in_group("player"):
		player.notify_collision()

func _on_bottom_pipe_body_entered(body):
	if body.is_in_group("player"):
		player.notify_collision()
