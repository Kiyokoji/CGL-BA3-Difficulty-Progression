extends CharacterBody2D
class_name Player

const Hook = preload("res://Scripts/hook_point.gd")

const UP = Vector2(0, -1)

signal grounded_update(is_grounded)
signal wall_grab_update(is_wallgrab)

@export var jump_on : bool = true
@export var dash_on : bool
@export var climb_on : bool
@export var wall_slide_on : bool
@export var attack_on : bool
@export var dodge_has_cool_down : bool

@export var jump_height 		: float = 3
@export var time_to_jump_apex 	: float = 0.8
@export var coyote_time_sec		: float = 0.1
@export var max_speed 			: float = 200
@export var acceleration 		: float = 35
@export var friction 			: float = 35
@export var dodge_speed 		: float = 3
@export var dodge_cooldown 		: float = 5
@export var walljump_speed 		: float = 1.3
@export var min_jump_time 		: float = 0.3
@export var wall_climp_speed 	: float = 30
@export var hook_distance		: float = 85
@export var launch_force		: float = 450

@export var current_hook : HookPoint

var gravity : float
@export var max_fall_speed : float = -300

var dodge
var jump_velocity
var jumped_height_counter = 0
var input_vector : Vector2 = Vector2.ZERO
# var velocity = Vector(0, 0)
var current_position = Vector2.ZERO
var position_update = Vector2.ZERO

var current_mouse_position = Vector2.ZERO

## BOOLS
var is_friction 		: bool = false
var is_attack_complete 	: bool = true
var is_dodge_animation 	: bool = false
var can_jump 			: bool = true
var is_jump_pressed	 	: bool = false
var is_jump_cancelled	: bool = false
var is_jump_cancellable	: bool = false
var is_jump_height_reached : bool = false
var is_jump_completed	: bool = false
var can_dodge 			: bool = true
var is_grabbing_wall	: bool = false
var just_walljumped 	: bool = false
var walljump 			: bool = false
var is_jumping 			: bool = false
var is_grounded 		: bool = false
var is_wallgrab 		: bool = false
var is_wall_above 		: bool = false
var is_coyote_started	: bool = false

var has_hooked			: bool = false

## ONREADY VARIABLES
@onready var animation_tree
@onready var sprite : Sprite2D = $Sprite2D
@onready var animation_state
@onready var hitbox
@onready var hitbox_position
@onready var hitbox_knockback
@onready var raycast_down : RayCast2D = $RaycastDown
@onready var raycast_right : RayCast2D = $RaycastRight
@onready var raycast_left : RayCast2D = $RaycastLeft
@onready var raycast_ledge_right : RayCast2D = $RaycastLedgeRight
@onready var raycast_ledge_left : RayCast2D = $RaycastLedgeLeft
@onready var hook_raycast : RayCast2D = $HookRaycast
@onready var line : Line2D = $Line2D
@onready var walljump_timeout : Timer = $WallJumpDisabler
@onready var attack_timer
@onready var pinjoint : PinJoint2D = $PinJoint2D
@onready var hook_detect : CollisionShape2D = $HookDetect/CollisionShape2D

## STATE MACHINE
enum CHARACTER_STATES {
	MOVE,
	JUMP,
	ATTACK,
	LAUNCH,
	DODGE,
	WALLGRAB,
	WALLHOLD
}

var state = CHARACTER_STATES.MOVE

#const SPEED = 130.0
#const JUMP_VELOCITY = -300.0


func _ready() -> void:
	gravity = (2 * jump_height) / pow(time_to_jump_apex, 2)
	jump_velocity = abs(gravity) * time_to_jump_apex
	
	hook_detect.shape.radius = hook_distance


func _process(delta):
	#player_input()
	mouse_input()
	pass


func _physics_process(delta):	
	#print("%s %s" % [velocity.y, -jump_height * 30])
	#print(is_jump_cancelled)
	player_input()
	calc_gravity()
	
	match state:
		CHARACTER_STATES.MOVE:
			move_state()
		CHARACTER_STATES.JUMP:
			jump_state()
		CHARACTER_STATES.ATTACK:
			attack_state()
		CHARACTER_STATES.LAUNCH:
			launch_state()
		CHARACTER_STATES.DODGE:
			dodge_state()
		CHARACTER_STATES.WALLGRAB:
			wall_grab_state()
		CHARACTER_STATES.WALLHOLD:
			hold_on_to_wall()	
	
	#animation_player()
	camera_movement()


func animation_player() -> void:
	pass
	

func mouse_input() -> void:
	if Input.is_action_just_pressed("hook") and not has_hooked:
		has_hooked = true
		hook_raycast.target_position = to_local(get_global_mouse_position())
		hook_raycast.force_raycast_update()
		if hook_raycast.is_colliding():
			var hook_pos = hook_raycast.get_collision_point()
			var collider = hook_raycast.get_collider()
			if (hook_pos - global_position).length() < hook_distance:
				if collider is Hook:
					pinjoint.global_position = hook_pos
					pinjoint.node_b = get_path_to(collider)
					current_hook = collider
					var direction = hook_pos - global_position
					state = CHARACTER_STATES.LAUNCH
				
	elif Input.is_action_just_released("hook") && has_hooked:
		has_hooked = false
		pinjoint.node_b = NodePath("")
		current_hook = null
	
	line.clear_points()
	if has_hooked:
		line.add_point(Vector2.ZERO)
		if current_hook == null:
			return
		line.add_point(to_local(current_hook.get_marker_pos()))


func player_input() -> void:
	input_vector.x = Input.get_axis("ui_left", "ui_right")
	input_vector.y = Input.get_axis("ui_up", "ui_down")
	# set animation tree parameters
	
	if Input.is_action_just_pressed("ui_accept") && jump_on:
		is_jump_pressed = true
		jump_time()
		if can_jump || walljump:
			is_jump_pressed = true
	
	if Input.is_action_just_released("ui_accept") && is_jump_pressed:
		is_jump_pressed = false
		#is_jump_cancelled = true
	
	if (Input.is_action_just_pressed("attack") && state != CHARACTER_STATES.WALLGRAB) && attack_on:
		state = CHARACTER_STATES.ATTACK
	
	if (Input.is_action_just_pressed("dodge") && can_dodge) && dash_on:
		state = CHARACTER_STATES.DODGE
	
	if (Input.is_action_just_pressed("hold_wall") && is_grabbing_wall) && climb_on:
		state = CHARACTER_STATES.WALLHOLD
	
	if Input.is_action_just_released("hold_wall") && is_grabbing_wall:
		state = CHARACTER_STATES.MOVE

func hold_on_to_wall() -> void:
	if raycast_left.enabled:
		if !raycast_left.is_colliding():
			state = CHARACTER_STATES.MOVE
		elif raycast_ledge_left.is_colliding():
			wall_climb()
			current_position = global_position
		else:
			position_update = global_position
			is_wall_above = false
			## this condition will stop the player 15 pixels from the top of the wall
			if current_position.y - position_update.y >= 15 && Input.is_action_just_pressed("ui_up"):
				velocity.y = 0
			else:
				wall_climb()
	
	if raycast_right.enabled:
		if !raycast_ledge_right.is_colliding():
			state = CHARACTER_STATES.MOVE
		elif raycast_ledge_right.is_colliding():
			wall_climb()
			current_position = global_position
		else:
			position_update = global_position
			is_wall_above = false
			## this condition will stop the player 15 pixels from the top of the wall
			if current_position.y - position_update.y >= 15 && Input.is_action_just_pressed("ui_up"):

				velocity.y = 0
			else:
				wall_climb()
	move_and_slide()

func wall_climb() -> void:
	pass


func move_state() -> void:
	# TODO hitbox.disabled = true
	player_physics()
	move_and_slide()


func player_physics() -> void:
	left_right_movement()
	ground_rules()
	jump_physics()


func left_right_movement() -> void:
	if just_walljumped:
		return
	
	if input_vector != Vector2.ZERO:
		velocity.x = move_toward(velocity.x, input_vector.x * max_speed, acceleration)
		if (abs(velocity.x) >= max_speed || input_vector.x != 0):
			is_friction = false
	else:
		is_friction = true


func ground_rules() -> void:
	if is_on_floor():
		can_dodge = true
		is_grabbing_wall = false
		can_jump = true
		is_coyote_started = false
		
		if is_jump_pressed:
			is_jumping = true
			is_jump_cancelled = false
			is_jump_height_reached = false
			is_jump_completed = false
			state = CHARACTER_STATES.JUMP
		
		if is_friction:
			velocity.x = move_toward(velocity.x, 0, friction)
		
		# we don't cast rays when we don't need to
		disable_raycasts()
	else:
		if !is_coyote_started: 
			coyote()
		if is_friction:
			velocity.x = move_toward(velocity.x, 0, friction * 0.5)
		
		if !raycast_down.is_colliding():
			if input_vector.x < 0:
				raycast_left.enabled = true
				raycast_ledge_left.enabled = true
			elif input_vector.x > 0:
				raycast_right.enabled = true
				raycast_ledge_right.enabled = true
			else:
				disable_raycasts()
			
			if (raycast_left.is_colliding() or raycast_right.is_colliding()) && wall_slide_on:
				state = CHARACTER_STATES.WALLGRAB


func launch_state() -> void:
	if current_hook == null:
		return
	velocity = (current_hook.get_marker_pos() - global_position).normalized() * launch_force
	reset_jump()
	move_and_slide()
	state = CHARACTER_STATES.MOVE
	pass


func attack_state() -> void:
	pass


func disable_raycasts() -> void:
	raycast_right.enabled = false
	raycast_left.enabled = false
	raycast_ledge_right.enabled = false
	raycast_ledge_left.enabled = false


func jump_state() -> void:
	if is_grabbing_wall && is_wall_above:
		do_walljump()
	else:
		velocity.y = -jump_velocity * 30
		can_jump = false
		walljump = false
		set_jump_cancellable()
	state = CHARACTER_STATES.MOVE
	move_and_slide()


func jump_physics() -> void:
	if !is_jumping && !is_on_floor():
		return
		
	if !is_jump_cancelled:
		#print("%s %s %s" % [is_jump_pressed, velocity.y, is_jump_cancellable])
		if !is_jump_pressed && velocity.y < 0 && is_jump_cancellable:
			is_jump_cancelled = true
			print("NO MORE JUMP")
			print(is_jump_cancelled)
	
	if is_jump_cancelled:
		is_jump_cancelled = false
		velocity.y = 0


func dodge_state() -> void:
	pass


func wall_grab_state() -> void:
	pass


func ledge_check() -> void:
	if raycast_ledge_left.is_colliding() || raycast_ledge_right.is_colliding():
		is_wall_above = true
	elif !raycast_ledge_left.is_colliding() || !raycast_ledge_right.is_colliding():
		is_wall_above = false


func calc_gravity() -> void:
	if state == CHARACTER_STATES.WALLGRAB:
		if velocity.y < 0 && (raycast_ledge_left.is_colliding()):
			velocity.y = 0
		else:
			velocity.y += gravity * 0.2
			velocity.y = clamp (velocity.y, max_fall_speed, 30)
	elif state == CHARACTER_STATES.WALLHOLD:
		pass
	else:
		velocity.y += gravity


func coyote() -> void:
	is_coyote_started = true
	await get_tree().create_timer(coyote_time_sec).timeout
	can_jump = false
	print("ya")


func jump_time() -> void:
	return
	await get_tree().create_timer(0.1).timeout
	is_jump_pressed = false


func reset_jump() -> void:
	can_jump = false
	walljump = false
	is_jumping = false
	is_jump_cancelled = false
	is_jump_height_reached = false
	is_jump_completed = false


func set_jump_cancellable() -> void:
	is_jump_cancellable = false
	await get_tree().create_timer(min_jump_time).timeout
	is_jump_cancellable = true


func walljump_time() -> void: 
	if walljump_timeout.is_stopped():
		walljump_timeout.start()


func calc_dodge_cooldown() -> void:
	pass


func just_walljumped_timer() -> void:
	pass


func attack_complete() -> void:
	pass


func perform_dodge() -> void:
	pass


func do_walljump() -> void:
	pass


func dodge_animation() -> void:
	pass


func camera_movement() -> void:
	pass


func _on_walljump_disabler_timeout():
	pass


func _on_hurtbox_area_entered(area):
	pass


func _on_hook_detect_area_entered(area):
	if area is Hook:
		area.set_close_active(true)


func _on_hook_detect_area_exited(area):
	if area is Hook:
		area.set_close_active(false)
