extends CharacterBody2D

@export_range(100.0, 1000.0) var speed: float = 300.0
@export_range(100.0, 1000.0) var jump_velocity: float = 400.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var facing_right_x_offset: float = 0
var facing_left_x_offset: float = 0

var facing_right: bool = true	

func _ready():	
	facing_right_x_offset = sprite.position.x
	facing_left_x_offset = -sprite.position.x

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = -jump_velocity

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
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