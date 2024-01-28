extends CharacterBody2D
@export var pipe_scene:PackedScene 
const X_SPEED = 250.0
const JUMP_VELOCITY = -650.0
const MAX_Y_VELOCITY = 900.0
const MIN_PIPE_Y_POS = 170
const MAX_PIPE_Y_POS = 790
const START_PIPE_X_POS = 600
const START_PIPE_OFFSET = (MAX_PIPE_Y_POS - MIN_PIPE_Y_POS)/3
const START_PIPE_GAP = 400
const MIN_PIPE_GAP = 300
const NUM_PIPES = 4
const TIME_ALIVE_TXT = "Time Alive: "
const NUM_PIPES_TXT = "Pipes Passed: "
const POS_TXT = "Y Position: "
const VEL_TXT = "Y Velocity: "
const SINCE_JUMP_TXT = "Frames Since Last Jump: "
const ITER_TXT = "Iteration #: "

var rng = RandomNumberGenerator.new()
# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var start_pos
var player_height
var pipe_offset
var pipe_gap = START_PIPE_GAP
var pipes = []
var pipes_passed
var time_alive
var num_iters
var can_update_doubles
var can_add_score
var frame
var jump_frame

func _ready():
	start_pos = position
	num_iters = 1
	player_height = $CollisionShape2D.shape.size.x
	for i in NUM_PIPES:
		var pipe = pipe_scene.instantiate()
		pipe.position.x = START_PIPE_X_POS + pipe_gap*i
		$"../PipesHolder".add_child(pipe)
		pipes.push_back(pipe)
	start()
	
func jump():
	jump_frame = frame
	velocity.y = JUMP_VELOCITY
	
func dont_jump():
	pass
	
func die():
	$UdpClient.send_msg("B," + str(snapped(time_alive, 0.01)) + ",end")
	num_iters += 1
	start()
	
func notify_collision():
	die()
	
func update_hud():
	$HUD/PipesPassed.text = NUM_PIPES_TXT + str(pipes_passed)
	if can_update_doubles:
		$HUD/TimeAlive.text = TIME_ALIVE_TXT + str(snapped(time_alive, 0.1))
		$HUD/Position.text = POS_TXT + str(snapped(position.y, 0.1))
		$HUD/Velocity.text = VEL_TXT + str(snapped(velocity.y, 0.1))
		can_update_doubles = false
		$HUD/SinceJump.text = SINCE_JUMP_TXT + str(frame - jump_frame)
	$HUD/Iter.text = ITER_TXT + str(num_iters)

func start():
	frame = 0
	can_add_score = false
	pipes_passed = 0
	time_alive = 0.0
	position = start_pos
	can_update_doubles = true
	pipe_offset = START_PIPE_OFFSET
	velocity.y = 0
	jump()
	update_hud()
	for i in pipes.size():
		pipes[i].position.x = START_PIPE_X_POS + pipe_gap*i
		pipes[i].position.y = rng.randi_range(MIN_PIPE_Y_POS + pipe_offset, MAX_PIPE_Y_POS - pipe_offset)
#	$"../PipesHolder/Pipe".position.y = rng.randi_range(MIN_PIPE_Y_POS + START_PIPE_OFFSET, MAX_PIPE_Y_POS - START_PIPE_OFFSET)

func _physics_process(delta):
	while $UdpClient.msg_waiting():
		print($UdpClient.get_msg())
	# Add the gravity.
	velocity.y += gravity * delta
	velocity.y = clampf(velocity.y, -MAX_Y_VELOCITY, MAX_Y_VELOCITY)
	# Handle Jump.
#	if Input.is_action_just_pressed("ui_accept"):
#		jump()
	# Move pipes
	if rng.randi_range(0,100) > 95:
		jump()
	var x_speed = X_SPEED * delta
	for i in pipes.size():
		pipes[i].position.x -= x_speed
	time_alive += delta
	move_and_slide()
	if !can_add_score and pipes[0].position.x + 82 >= position.x and pipes[0].position.x - 50 < position.x + 32:
		can_add_score = true
	if pipes[0].position.x + 82 < position.x and can_add_score:
		can_add_score = false
		pipes_passed += 1
	if pipes[0].position.x < -50: 
		pipes.push_back(pipes.pop_front())
		pipes[NUM_PIPES-1].position.x = pipes[NUM_PIPES-2].position.x + pipe_gap
	update_hud()
	frame+=1

func _on_floor_body_entered(body):
	die()

func _on_timer_timeout():
	can_update_doubles = true
