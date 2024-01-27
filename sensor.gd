extends Node2D
var colliding

# Called when the node enters the scene tree for the first time.
func _ready():
	start()

func start():
	colliding = 0
	$Sprite2D.modulate = Color.GREEN

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if colliding:
		$Sprite2D.modulate = Color.RED
	else:
		$Sprite2D.modulate = Color.GREEN
func _on_area_2d_area_entered(area):
	colliding+=1

func _on_area_2d_area_exited(area):
	colliding-=1
