extends CharacterBody2D

@export_group("Movement")

## The maximum horizontal speed of the player running in px/s.
## This is also the maximum speed player can acccelerate to when jumping.
@export_range(100.0, 2000.0) var speed: float = 250.0

## The acceleration of the player when running on ground in px/s².
@export_range(100.0, 10000.0) var acceleration: float = 1500.0

## The deceleration (braking) of the player when running on ground in px/s².
@export_range(100.0, 10000.0) var deceleration: float = 1750.0

## The acceleration of the player when moving in the air in px/s².
@export_range(100.0, 10000.0) var air_acceleration: float = 1250.0

## The deceleration (braking) of the player when moving in the air in px/s².
@export_range(100.0, 10000.0) var air_deceleration: float = 1500.0

@export_group("Jumping")

## The vertical velocity of the player when jumping in px/s.
## This determines how high the player can jump, depending on the gravity multiplier.
@export_range(100.0, 1000.0) var jump_velocity: float = 450.0

## The default gravity multiplier of the player. It's simply multiplying the gravity vector
## with this value. It's affected by the global gravity and mofidiers, like Area2D regions.
## This value is also used when falling without jumping.
@export_range(0.0, 10.0) var gravity_multiplier: float = 1.0

## The gravity multiplier of the player when falling after jumping.
## This multiplier is applied on top of the standard gravity_multiplier.
## This is intended to make the player fall faster after the upward phase of jumping
## is over.
@export_range(0.0, 10.0) var gravity_fall_multiplier: float = 2.5

## The maximum vertical velocity (px/s) of the player when falling (due to jumping or not).
## This can also be used to simulate gliding when set to a low value.
@export_range(0.0, 2000.0) var vertical_terminal_velocity: float = 750.0

## The multiplier of the player's vertical velocity applied when releasing the jump button.
## This allows the player to release jump button earlier to make the jump shorter.
## In other words, the maximum jump height can be achieved by holding the jump button.
## When set to 1.0, the release of the jump button won't affect the jump height.
## Setting this to 0.0, will make the player instantly start falling.
@export_range(-5.0, 5.0) var jump_release_stop_multiplier: float = 0.6

@export_group("Assists")
## The coyote time duration in seconds.
## The player will be able to jump for this extra amount of time after
## stopped touching the ground. It reduces the risk of the player falling off the platform
## when intended to jump.
@export_range(0.0, 1.0) var coyote_duration: float = 0.1

## The jump buffer duration in seconds.
## If the player presses the jump button before the character touches the ground, the
## jump buffer will be activated. If the character touches the ground within the time
## specified by this value, the jump will happen automatically.
## This is to avoid situations where the player presses "jump" too early. This simply
## captures the intent of jumping for the specified amount of time.
@export_range(0.0, 1.0) var jump_buffer_duration: float = 0.12


var is_jumping: bool = false ## Is the reason for the player to be in the air due to a jump?
var was_on_floor: bool = false ## Was the player on the floor in the previous (physics) frame?
var is_coyote: bool = false ## Is the coyote time timer active?
var is_jump_buffer: bool = false ## Is the jump buffer timer active?

@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_buffer_timer: Timer = $JumpBufferTimer

# Animation
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
var facing_right_x_offset: float = 0 ## The offset of the sprite when facing right - due to non-centered graphics.
var facing_left_x_offset: float = 0 ## The offset of the sprite when facing left - due to non-centered graphics.
var facing_right: bool = true ## Is the player facing right? (sprite flipping)

# Particles
@onready var run_particles: GPUParticles2D = $RunParticles
@onready var jump_particles: GPUParticles2D = $JumpParticles
@onready var land_particles: GPUParticles2D = $JumpParticles

# Sounds
@onready var jump_player: AudioStreamPlayer2D = $JumpPlayer
@onready var land_player: AudioStreamPlayer2D = $LandPlayer
@onready var step_player: AudioStreamPlayer2D = $StepPlayer
var is_playing_step: bool = false ## Is the step sound already playing?


func _ready():
	# Capture the x offset of the sprite in case the player graphics
	# is not in the center of the sprite.
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
			velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, deceleration * delta)
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
				jump()
				is_coyote = false
				coyote_timer.stop()
			elif not is_jump_buffer:
				start_jump_buffer()

		# Add extra gravity when falling
		if is_jumping and velocity.y > 0:
			velocity += gravity * gravity_fall_multiplier * delta
		else:
			velocity += gravity * delta

		# Released jump - increase gravity
		if velocity.y < 0 and Input.is_action_just_released("ui_accept"):
			velocity.y = velocity.y * jump_release_stop_multiplier

		# Limit vertical velocity
		velocity.y = clampf(velocity.y, -9999999.0, vertical_terminal_velocity)

		var direction = Input.get_axis("ui_left", "ui_right")
		if direction:
			velocity.x = move_toward(velocity.x, direction * speed, air_acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, air_deceleration * delta)
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
		# LANDING DETECTED!
		if not was_on_floor:
			land_particles.emitting = true
			animation_player.play("land")
			land_player.pitch_scale = randf_range(0.8, 1.2)
			land_player.play()

		if velocity.x != 0:
			sprite.play("run")
			run_particles.emitting = true
			if not is_playing_step:
				step_player.pitch_scale = randf_range(0.85, 1.15)
				step_player.play()
				is_playing_step = true
		else:
			sprite.play("idle")

	else:
		# JUMP DETECTED!
		if was_on_floor and is_jumping:
			jump_particles.emitting = true
			animation_player.play("jump")
			jump_player.pitch_scale = randf_range(0.8, 1.2)
			jump_player.play()

		if velocity.y < 0:
			sprite.play("jump")
		else:
			sprite.play("fall")


# Initiate jump if pressed jump button
func jump():
	velocity.y = -jump_velocity
	is_jumping = true

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


func _on_step_player_finished():
	is_playing_step = false
