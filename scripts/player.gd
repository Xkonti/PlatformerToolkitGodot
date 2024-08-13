extends CharacterBody2D

@export_range(100.0, 1000.0) var speed: float = 300.0
@export_range(0.0, 100.0) var acceleration: float = 1.0
@export_range(0.0, 100.0) var deceleration: float = 1.0

@export_range(100.0, 1000.0) var jump_velocity: float = 400.0
@export_range(0.0, 10.0) var gravity_multiplier: float = 1.0
@export_range(0.0, 10.0) var gravity_fall_multiplier: float = 2.0
@export_range(0.0, 20000.0) var horizontal_terminal_velocity: float = 1000.0
@export_range(0.0, 2000.0) var vertical_terminal_velocity: float = 300.0


var is_jumping: bool = false
var terminal_velocity: Vector2 = Vector2.ZERO



# Animation
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var facing_right_x_offset: float = 0
var facing_left_x_offset: float = 0
var facing_right: bool = true	

func _ready():	
	facing_right_x_offset = sprite.position.x
	facing_left_x_offset = -sprite.position.x
	terminal_velocity = Vector2(horizontal_terminal_velocity, vertical_terminal_velocity)

func _physics_process(delta):

	# On ground
	if is_on_floor():
		is_jumping = false

	if Input.is_action_just_pressed("ui_accept"):
		velocity.y = -jump_velocity
		is_jumping = true

	# In air
	else:
		var gravity = get_gravity() * gravity_multiplier

		# Add extra gravity when falling
		if is_jumping and velocity.y > 0:
			velocity += gravity * gravity_fall_multiplier * delta
		else:
			velocity += gravity * delta

		# Limit vertical velocity
		velocity.y = clampf(velocity.y, -9999999.0, vertical_terminal_velocity)

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration * speed * delta)
	if direction > 0:
		facing_right = true
	elif direction < 0:
		facing_right = false

	move_and_slide()

func _process(_delta):

	# Animate and adjust the sprite

	# Flip the sprite depending on the facing direction
	sprite.flip_h = not facing_right
	sprite.position.x = facing_right_x_offset if facing_right else facing_left_x_offset

	# Update the animation
	if is_on_floor():
		if velocity.x != 0:
			sprite.play("run")
		else:
			sprite.play("idle")
	else:
		if velocity.y < 0:
			sprite.play("jump")
		else:
			sprite.play("fall")
