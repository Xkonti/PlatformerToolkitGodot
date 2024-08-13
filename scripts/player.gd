extends CharacterBody2D

@export_range(100.0, 1000.0) var speed: float = 300.0
@export_range(0.0, 100.0) var acceleration: float = 1.0
@export_range(0.0, 100.0) var deceleration: float = 1.0
@export_range(0.0, 100.0) var air_acceleration: float = 0.8
@export_range(0.0, 100.0) var air_deceleration: float = 0.8

@export_range(100.0, 1000.0) var jump_velocity: float = 400.0
@export_range(0.0, 10.0) var gravity_multiplier: float = 1.0
@export_range(0.0, 10.0) var gravity_fall_multiplier: float = 2.0
@export_range(0.0, 2000.0) var vertical_terminal_velocity: float = 300.0
@export_range(0.0, 1.0) var jump_release_stop_multiplier: float = 0.5

@export_range(0.0, 1.0) var coyote_duration: float = 0.1
@export_range(0.0, 1.0) var jump_buffer_duration: float = 0.12


var is_jumping: bool = false
var was_on_floor: bool = false
var is_coyote: bool = false
var is_jump_buffer: bool = false

@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_buffer_timer: Timer = $JumpBufferTimer

# Animation
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var facing_right_x_offset: float = 0
var facing_left_x_offset: float = 0
var facing_right: bool = true

# Particles
@onready var run_particles: GPUParticles2D = $RunParticles
@onready var jump_particles: GPUParticles2D = $JumpParticles
@onready var land_particles: GPUParticles2D = $JumpParticles

func _ready():	
	facing_right_x_offset = sprite.position.x
	facing_left_x_offset = -sprite.position.x
	# Engine.time_scale = 0.1

func _physics_process(delta):

	# On ground
	if is_on_floor():
		is_jumping = false

		if is_jump_buffer and not was_on_floor:
			jump()
			is_jump_buffer = false
			jump_buffer_timer.stop()
		elif Input.is_action_just_pressed("ui_accept"):
			jump()

		var direction = Input.get_axis("ui_left", "ui_right")
		if direction:
			velocity.x = move_toward(velocity.x, direction * speed, acceleration * speed * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, deceleration * speed * delta)
		if direction > 0:
			facing_right = true
		elif direction < 0:
			facing_right = false

		was_on_floor = true

	# In air
	else:
		var gravity = get_gravity() * gravity_multiplier

		if was_on_floor and not is_jumping:
			start_coyote(delta)

		if Input.is_action_just_pressed("ui_accept"):
			if is_coyote:
				velocity.y = -jump_velocity
				is_jumping = true
				is_coyote = false
				coyote_timer.stop()
			elif not is_jump_buffer:
				start_jump_buffer()

		# Add extra gravity when falling
		if is_jumping and velocity.y > 0:
			velocity += gravity * gravity_fall_multiplier * delta
		else:
			velocity += gravity * delta

		if velocity.y < 0 and Input.is_action_just_released("ui_accept"):
			velocity.y = velocity.y * jump_release_stop_multiplier

		# Limit vertical velocity
		velocity.y = clampf(velocity.y, -9999999.0, vertical_terminal_velocity)

		var direction = Input.get_axis("ui_left", "ui_right")
		if direction:
			velocity.x = move_toward(velocity.x, direction * speed, air_acceleration * speed * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, air_deceleration * speed * delta)
		if direction > 0:
			facing_right = true
		elif direction < 0:
			facing_right = false

		was_on_floor = false
	

	move_and_slide()

func _process(_delta):

	# Animate and adjust the sprite

	# Flip the sprite depending on the facing direction
	sprite.flip_h = not facing_right
	sprite.position.x = facing_right_x_offset if facing_right else facing_left_x_offset

	# Update the animation
	run_particles.emitting = false
	if is_on_floor():
		if not was_on_floor:
			land_particles.emitting = true

		if velocity.x != 0:
			sprite.play("run")
			run_particles.emitting = true
		else:
			sprite.play("idle")

	else:
		if velocity.y < 0:
			sprite.play("jump")
		else:
			sprite.play("fall")


# Initiate jump if pressed jump button
func jump():
	velocity.y = -jump_velocity
	is_jumping = true
	jump_particles.emitting = true

func start_coyote(delta):
	coyote_timer.start(coyote_duration - delta)
	is_coyote = true

func _on_coyote_timer_timeout():
	is_coyote = false

func start_jump_buffer():
	jump_buffer_timer.start(jump_buffer_duration)
	is_jump_buffer = true

func _on_jump_buffer_timer_timeout():
	is_jump_buffer = false
