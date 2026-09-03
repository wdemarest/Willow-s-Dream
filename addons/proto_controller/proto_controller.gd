# ProtoController v1.0 by Brackeys
# CC0 License
# Intended for rapid prototyping of first-person games.
# Happy prototyping!

extends CharacterBody3D


var emberPrefab = preload("res://ember.tscn")

@export var voxel_terrain : VoxelTerrain;

@onready var voxel_tool : VoxelTool = voxel_terrain.get_voxel_tool()



## Can we move around?
@export var can_move : bool = true
## Are we affected by gravity?
@export var has_gravity : bool = true
## Can we press to jump?
@export var can_jump : bool = true
## Can we hold to run?
@export var can_sprint : bool = false
## Can we press to enter freefly mode (noclip)?
@export var can_freefly : bool = false

@export_group("Speeds")
## Look around rotation speed.
@export var look_speed : float = 0.002
## Normal speed.
@export var base_speed : float = 7.0
## Speed of jump.
@export var jump_velocity : float = 4.5
## How fast do we run?
@export var sprint_speed : float = 10.0
## How fast do we freefly?
@export var freefly_speed : float = 25.0

## when you're heading downward at least this fast, gravity no longer affects you.
@export var max_fall_speed : float = 35;
## how fast you throw the hook
@export var throw_vel : float = 10.0
## how fast you pull yourself toward the hook
@export var player_reel_speed : float = 3.0
## minimum dot product for the hook to attach
@export var hook_attach_threshold : float = 0;
## how close you can reel yourself into the hook
@export var min_reel_dist : float = 1;
## how far you must be from the near side of the sphere you're placing 
@export var placement_min_dist : float = 5;
## radius of placement
@export var placement_radius : float = 5;

@export_group("Input Actions")
## Name of Input Action to move Left.
@export var input_left : String = "ui_left"
## Name of Input Action to move Right.
@export var input_right : String = "ui_right"
## Name of Input Action to move Forward.
@export var input_forward : String = "ui_up"
## Name of Input Action to move Backward.
@export var input_back : String = "ui_down"
## Name of Input Action to Jump.
@export var input_jump : String = "ui_accept"
## Name of Input Action to Sprint.
@export var input_sprint : String = "sprint"
## Name of Input Action to toggle freefly mode.
@export var input_freefly : String = "freefly"




var mouse_captured : bool = false
var look_rotation : Vector2
var move_speed : float = 0.0
var freeflying : bool = false

var hookOut : bool = false;
var ropeLength = null;


## IMPORTANT REFERENCES
@onready var head: Node3D = $Head
@onready var collider: CollisionShape3D = $Collider

@onready var hook: RigidBody3D = $"../Hook"

func _ready() -> void:
	check_input_mappings()
	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x

func _unhandled_input(event: InputEvent) -> void:
	# Mouse capturing
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		capture_mouse()
	if Input.is_key_pressed(KEY_ESCAPE):
		release_mouse()
	
	# Look around
	if mouse_captured and event is InputEventMouseMotion:
		rotate_look(event.relative)
	
	# Toggle freefly mode
	if can_freefly and Input.is_action_just_pressed(input_freefly):
		if not freeflying:
			enable_freefly()
		else:
			disable_freefly()

func _physics_process(delta: float) -> void:
	# If freeflying, handle freefly and nothing else
	if can_freefly and freeflying:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var motion := (head.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		motion *= freefly_speed * delta
		move_and_collide(motion)
		return
	
	# Apply gravity to velocity
	if has_gravity:
		if not is_on_floor():
			if velocity.y > -max_fall_speed:
				velocity += get_gravity() * delta;
			else:
				print("WOAH SO FAST")

	# Apply jumping
	if can_jump:
		if Input.is_action_just_pressed(input_jump) and is_on_floor():
			velocity.y = jump_velocity

	# Modify speed based on sprinting
	if (can_sprint or (can_freefly and freeflying)) and Input.is_action_pressed(input_sprint):
			move_speed = sprint_speed
	else:
		move_speed = base_speed

	# Apply desired movement to velocity
	if can_move:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if is_on_floor():
			if move_dir:
				velocity.x = move_dir.x * move_speed
				velocity.z = move_dir.z * move_speed
			else:
				velocity.x = move_toward(velocity.x, 0, move_speed)
				velocity.z = move_toward(velocity.z, 0, move_speed)
		elif move_dir:
			var currentVelInDir = velocity.dot(move_dir)
			if currentVelInDir < move_speed:
				velocity += move_dir * (min(move_speed * delta, move_speed - currentVelInDir));
	else:
		velocity.x = 0
		velocity.y = 0
	
	var pos_before: Vector3 = $RopeConnect.global_position;
	
	# Use velocity to actually move
	move_and_slide()
	
	simRope(pos_before, delta);
	
	if hookOut:
		hook.gravity_scale = 1;
		
		hook.find_child("FogGlow").light_volumetric_fog_energy = 16;
		
	else:
		hook.gravity_scale = 0;
		hook.linear_velocity = Vector3(0,0,0);
		
		hook.find_child("FogGlow").light_volumetric_fog_energy = 2;
		
		
		var distToHook : float = $RopeConnect.global_position.distance_to(hook.position)
		
		var minDistBeforeSnap : float = 0.1;
		
		var distToReelThisFrame : float = max(distToHook * 3, 100) * delta;
		
		if(distToHook < minDistBeforeSnap or distToReelThisFrame > distToHook):
			distToReelThisFrame = distToHook
		
		var dirToRopeConnect : Vector3 = ($RopeConnect.global_position - hook.position).normalized();
		hook.global_position += dirToRopeConnect * distToReelThisFrame;
		
	
	
	
	# Dig
	if Input.is_action_just_pressed("dig"):
		
		if hookOut:
			voxel_tool.mode = VoxelTool.MODE_REMOVE
			
			voxel_tool.do_sphere($"../Hook".global_position, 3.0)
			print("DIGGING");
			
			hookNoLongerOut()
	
	# Place
	if Input.is_action_just_pressed("place"):
		
		if global_position.distance_to(hook.global_position) > placement_radius + placement_min_dist:
			
			voxel_tool.mode = VoxelTool.MODE_ADD
			
			voxel_tool.do_sphere($"../Hook".global_position, placement_radius)
			print("PLACING");
			
			hookNoLongerOut()
		
	
	#throw
	if Input.is_action_just_pressed("throw"):
		hookOut = true;
		ropeLength = null;
		hook.set("freeze", false);
		
		hook.global_position = $Head/Camera3D/ThrowStart.global_position;
		
		var dir : Vector3 = hook.global_position - $Head/Camera3D.global_position;
		var initVel : Vector3 = dir.normalized() * throw_vel;
		
		hook.linear_velocity = initVel + velocity;
	
	#release throw
	if Input.is_action_just_released("throw"):
		hookNoLongerOut()
	
	
	if Input.is_action_just_pressed("stall"):
		velocity *= 0;
		
	#STEELPUSH
	#if Input.is_action_pressed("thumb 2 input") and ropeLength:
			#var dirToHook: Vector3 = (hook.global_position - $RopeConnect.global_position).normalized();
			#velocity += -dirToHook * 0.3;
			#ropeLength += 10;
			
	if Input.is_action_just_pressed("ember"):
		#var ember = emberPrefab.instantiate()
		var ember = load("res://ember.tscn").instantiate()
		add_child(ember)
		ember.reparent($"..")
		
		ember.global_position = $Head/Camera3D/ThrowStart.global_position;
		var dir : Vector3 = ember.global_position - $Head/Camera3D.global_position;
		var initVel : Vector3 = dir.normalized() * throw_vel;
		
		ember.linear_velocity = initVel + velocity;
		
		
		

func hookNoLongerOut() -> void:
	hookOut = false;
	ropeLength = null;
	hook.set("freeze", false);



func simRope(pos_before: Vector3, delta: float) -> void:
	if ropeLength:
		var distToHook = $RopeConnect.global_position.distance_to(hook.position)
		
		ropeLength = min(ropeLength, distToHook);
		
		var dirToHook: Vector3 = (hook.global_position - $RopeConnect.global_position).normalized();
		
		if distToHook > ropeLength:
			
			global_position += dirToHook * (distToHook - ropeLength);
			
			var radial_speed: float = velocity.dot(-dirToHook);
			if radial_speed > 0.0:
				velocity += dirToHook * radial_speed
		
		if Input.is_action_pressed("reel") and distToHook > min_reel_dist:
			setMinVelInDirection(dirToHook, player_reel_speed);


func setMinVelInDirection(direction : Vector3, minVel : float):
	var currentVelInDir = velocity.dot(direction)
	if currentVelInDir < minVel:
		velocity += direction * (minVel - currentVelInDir);



## Rotate us to look around.
## Base of controller rotates around y (left/right). Head rotates around x (up/down).
## Modifies look_rotation based on rot_input, then resets basis and rotates by look_rotation.
func rotate_look(rot_input : Vector2):
	look_rotation.x -= rot_input.y * look_speed
	look_rotation.x = clamp(look_rotation.x, deg_to_rad(-85), deg_to_rad(85))
	look_rotation.y -= rot_input.x * look_speed
	transform.basis = Basis()
	rotate_y(look_rotation.y)
	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)


func enable_freefly():
	collider.disabled = true
	freeflying = true
	velocity = Vector3.ZERO

func disable_freefly():
	collider.disabled = false
	freeflying = false


func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true


func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false


## Checks if some Input Actions haven't been created.
## Disables functionality accordingly.
func check_input_mappings():
	if can_move and not InputMap.has_action(input_left):
		push_error("Movement disabled. No InputAction found for input_left: " + input_left)
		can_move = false
	if can_move and not InputMap.has_action(input_right):
		push_error("Movement disabled. No InputAction found for input_right: " + input_right)
		can_move = false
	if can_move and not InputMap.has_action(input_forward):
		push_error("Movement disabled. No InputAction found for input_forward: " + input_forward)
		can_move = false
	if can_move and not InputMap.has_action(input_back):
		push_error("Movement disabled. No InputAction found for input_back: " + input_back)
		can_move = false
	if can_jump and not InputMap.has_action(input_jump):
		push_error("Jumping disabled. No InputAction found for input_jump: " + input_jump)
		can_jump = false
	if can_sprint and not InputMap.has_action(input_sprint):
		push_error("Sprinting disabled. No InputAction found for input_sprint: " + input_sprint)
		can_sprint = false
	if can_freefly and not InputMap.has_action(input_freefly):
		push_error("Freefly disabled. No InputAction found for input_freefly: " + input_freefly)
		can_freefly = false



func _on_hook_collided(dotProduct:float) -> void:
	if not ropeLength and hookOut and dotProduct > hook_attach_threshold:
		ropeLength = position.distance_to(hook.position)+1000;
		hook.set_deferred("freeze", true);
