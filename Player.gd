extends CharacterBody2D
@export var pipe_scene:PackedScene 
const X_SPEED = 250.0
const JUMP_VELOCITY = -650.0
const MAX_Y_VELOCITY = 900.0
const MIN_PIPE_Y_POS = 170
const MAX_PIPE_Y_POS = 790
const START_PIPE_X_POS = 600
const START_PIPE_OFFSET = (MAX_PIPE_Y_POS - MIN_PIPE_Y_POS)/4
const MIN_PIPE_OFFSET = 20
const START_PIPE_GAP = 400
const MIN_PIPE_GAP = 300
const NUM_PIPES = 4
const TIME_ALIVE_TXT = "Time Alive: "
const NUM_PIPES_TXT = "Pipes Passed: "
const POS_TXT = "Y Position: "
const VEL_TXT = "Y Velocity: "
const AVG_SURVIVE_TXT = "Average Survival Time: "
const MAX_SURVIVE_TXT = "Max Survival Time: "
const ITER_TXT = "Iteration #: "
const PACKETS_SENT_TXT = "Packets Sent: "
const PACKETS_RCVD_TXT = "Packets Received: "
#const START_NOISE = 0.002
const REWARD = 0.08
const PENALTY = 0.07
const REWARD_BUFFER = 0.02
const GETS_HARDER = false
const SVR_ADDR = "localhost"
const SVR_PORT = 5000
var rng = RandomNumberGenerator.new()
# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var start_pos
var player_height
var pipe_offset
var pipe_gap
var pipes = []
var pipes_passed
var time_alive
var num_iters
var can_update_doubles
var can_add_score
var jump_time
var total_survival
var avg_survival
var max_survival
var states_and_hypotheses:Dictionary
var iteration_decisions:Dictionary
var packets_sent
var packets_received
var id

func _ready():
	id = rng.randi_range(1,999999)
	get_window().title += " - id:" + str(id)
	packets_sent = 0
	packets_received = 0
	pipe_gap = START_PIPE_GAP
	pipe_offset = START_PIPE_OFFSET
	states_and_hypotheses = {}
	iteration_decisions = {}
	start_pos = position
	total_survival = 0.0
	avg_survival = 0.0
	max_survival = 0.0
	num_iters = 0
	player_height = $CollisionShape2D.shape.size.x
	for i in NUM_PIPES:
		var pipe = pipe_scene.instantiate()
		pipe.position.x = START_PIPE_X_POS + pipe_gap*i
		$"../PipesHolder".add_child(pipe)
		pipes.push_back(pipe)
	start()
	
func jump():
	jump_time = time_alive
	velocity.y = JUMP_VELOCITY
	
func send_state_and_hypothesis_udp(update):
	$UdpClient.send_msg("0," + update + "," + str(id))
	packets_sent += 1
	
func send_state_timelived_jumped(state:String, timelived:float, jumped:bool):
	$UdpClient.send_msg("1," + state + "," + str(timelived) +"," + str(jumped) + "," + str(id))
	packets_sent += 1
	
func send_time_lived():
	$UdpClient.send_msg("2," + str(time_alive) + "," + str(id))
	packets_sent += 1
	
func send_dead_notice():
	$UdpClient.send_msg("3," + str(id))
	packets_sent += 1
	
func make_jump_decision() -> bool:
	var state = ""
	for eye in $SensorHolder.get_children():
		if eye.colliding:
			state += "1"
		else:
			state += "0"
#	state += "-" + str(frame - jump_frame)
#	state += str(int(velocity.y < 500.0))
	if states_and_hypotheses.has(state):
		var jump_incentive = states_and_hypotheses.get(state)
#		send_state_and_hypothesis_udp(state + "," + str(jump_incentive))
		var jumping = jump_incentive > 0.5
		var action = {"time": time_alive, "jumped": jumping}
		iteration_decisions[state] = action
		return jumping
	else:
#		print("discovered new state")
#		print("memory size now: " + str(states_and_outcomes.size()))
		var new_hypothesis = 0.5 #+ rng.randf_range(-START_NOISE, START_NOISE)
		states_and_hypotheses[state] = new_hypothesis
		send_state_and_hypothesis_udp(state + "," + str(new_hypothesis))
		var jumping = false
		var action = {"time": time_alive, "jumped": jumping}
		iteration_decisions[state] = action
		return jumping

	
func die():
	total_survival += time_alive
	#recalculate average survival time
	avg_survival = total_survival/float(num_iters)
	#decide whether to reward or punish lifetime choices
#	var positive_reward = time_alive - REWARD_BUFFER > avg_survival
#	print("positive_reward:" + str(positive_reward))
	var keys = iteration_decisions.keys()
	#reward/punish actions this lifetime
	for key in keys:
		var time_and_action = iteration_decisions.get(key)
#		var hypothesis = states_and_hypotheses.get(key)
#		print("state:" + key)
#		print(str(time_and_action))
#		print("jumped"+str(time_and_action.get("jumped")))
		send_state_timelived_jumped(key,time_alive,time_and_action.get("jumped"))
#		if positive_reward:
#			if time_and_action.get("jumped"):
#				states_and_hypotheses[key] = lerpf(hypothesis, 1.0, REWARD)
#			else:
#				states_and_hypotheses[key] = lerpf(hypothesis, 0.0, REWARD)
#		else:
#			if time_and_action.get("jumped"):
#				states_and_hypotheses[key] = lerpf(hypothesis, 0.0, PENALTY)
#			else:
#				states_and_hypotheses[key] = lerpf(hypothesis, 1.0, PENALTY)
#		var new_hypothesis = states_and_hypotheses.get(key)#+ rng.randf_range(-START_NOISE, START_NOISE)
	iteration_decisions = {}
	send_time_lived()
	if time_alive > max_survival:
		max_survival = time_alive
	start()
#	print("packets sent: " + str(packets_sent))
# just used to test that python solution works the same as gd_script lerp()
#func my_lerpf(a:float, b:float, f:float) -> float:
#	return (a * (1.0 - f)) + (b * f)

func notify_collision():
	die()
	
func kill_app():
	send_dead_notice()
	get_tree().quit() # default behavior
	
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		send_dead_notice()
		get_tree().quit() # default behavior
	
func update_hud():
	$HUD/PipesPassed.text = NUM_PIPES_TXT + str(pipes_passed)
	if can_update_doubles:
		$HUD/TimeAlive.text = TIME_ALIVE_TXT + str(snapped(time_alive, 0.1))
		$HUD/Position.text = POS_TXT + str(snapped(position.y, 0.1))
		$HUD/Velocity.text = VEL_TXT + str(snapped(velocity.y, 0.1))
		can_update_doubles = false
		$HUD/AvgSurvive.text = AVG_SURVIVE_TXT + str(snapped(avg_survival, 0.01))
		$HUD/MaxSurvive.text = MAX_SURVIVE_TXT + str(snapped(max_survival, 0.01))
	$HUD/Iter.text = ITER_TXT + str(num_iters)
	$HUD/PacketsSent.text = PACKETS_SENT_TXT + str(packets_sent)
	$HUD/PacketsReceived.text = PACKETS_RCVD_TXT + str(packets_received)

func start():
	num_iters +=1
	can_add_score = false
	pipes_passed = 0
	time_alive = 0.0
	position = start_pos
	can_update_doubles = true
	pipe_offset = START_PIPE_OFFSET
	pipe_gap = START_PIPE_GAP
	velocity.y = 0
	jump()
	update_hud()
	for i in pipes.size():
		pipes[i].position.x = START_PIPE_X_POS + pipe_gap*i
		pipes[i].position.y = rng.randi_range(MIN_PIPE_Y_POS + pipe_offset, MAX_PIPE_Y_POS - pipe_offset)
#	$"../PipesHolder/Pipe".position.y = rng.randi_range(MIN_PIPE_Y_POS + START_PIPE_OFFSET, MAX_PIPE_Y_POS - START_PIPE_OFFSET)

func _physics_process(delta):
	while $UdpClient.msg_waiting():
		var message = $UdpClient.get_msg()
		if message[0] == "_":
			packets_received += 1
			var arr = message.split(",")
			if arr[0] == "_1":
				states_and_hypotheses[arr[1]] = float(arr[2])
			elif arr[0] == "_2":
				if arr[1] == str(id):
					kill_app()
		
	# Add the gravity.
	velocity.y += gravity * delta
	velocity.y = clampf(velocity.y, -MAX_Y_VELOCITY, MAX_Y_VELOCITY)
	# Human jump
#	if Input.is_action_just_pressed("ui_accept"):
#		jump()
	if make_jump_decision():
		jump()
	
	# Move pipes
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
		if GETS_HARDER:
			pipe_gap = move_toward(pipe_gap, MIN_PIPE_GAP, 1.0)
			pipe_offset = move_toward(pipe_offset, MIN_PIPE_OFFSET, 1.0)
	if pipes[0].position.x < -50: 
		pipes.push_back(pipes.pop_front())
		pipes[NUM_PIPES-1].position.x = pipes[NUM_PIPES-2].position.x + pipe_gap
		pipes[NUM_PIPES-1].position.y = rng.randi_range(MIN_PIPE_Y_POS + pipe_offset, MAX_PIPE_Y_POS - pipe_offset)
	update_hud()

func _on_floor_body_entered(body):
	die()

func _on_timer_timeout():
	can_update_doubles = true
