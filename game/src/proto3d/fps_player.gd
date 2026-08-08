## Контроллер от первого лица для прототипа хоррора.
##
## Всё, что нужно для оценки картинки: ходьба, обзор мышью, фонарик,
## покачивание камеры при шаге. Никакой боёвки — как и в 2D-версии,
## опасность здесь в атмосфере, а не в противнике.
extends CharacterBody3D

@export var walk_speed := 2.2
@export var run_speed := 4.0
@export var mouse_sensitivity := 0.0022
## Насколько сильно камера качается при ходьбе.
@export var bob_amount := 0.035
@export var bob_speed := 9.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight

var _bob_time := 0.0
var _base_height := 0.0


func _ready() -> void:
	_base_height = head.position.y
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * mouse_sensitivity)
		head.rotate_x(-motion.relative.y * mouse_sensitivity)
		# Не даём свернуть шею.
		head.rotation.x = clampf(head.rotation.x, -1.4, 1.4)

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event.is_action_pressed("interact"):
		flashlight.visible = not flashlight.visible


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var input := Input.get_vector("move_left", "move_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	var speed := run_speed if Input.is_action_pressed("drs") else walk_speed

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()
	_update_bob(delta, direction.length() > 0.1)


## Покачивание камеры — самая дешёвая вещь, отличающая «камеру летает»
## от «человек идёт».
func _update_bob(delta: float, moving: bool) -> void:
	if moving and is_on_floor():
		_bob_time += delta * bob_speed
		var offset := sin(_bob_time) * bob_amount
		head.position.y = _base_height + offset
		# Лёгкий крен в стороны добавляет веса шагу.
		head.rotation.z = cos(_bob_time * 0.5) * 0.006
	else:
		_bob_time = 0.0
		head.position.y = lerpf(head.position.y, _base_height, 1.0 - exp(-8.0 * delta))
		head.rotation.z = lerpf(head.rotation.z, 0.0, 1.0 - exp(-8.0 * delta))
