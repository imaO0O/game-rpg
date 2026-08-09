## Контроллер от первого лица для прототипа хоррора.
##
## Всё, что нужно для оценки картинки: ходьба, обзор мышью, фонарик,
## покачивание камеры при шаге. Никакой боёвки — как и в 2D-версии,
## опасность здесь в атмосфере, а не в противнике.
extends CharacterBody3D

## Слой, который видят только камеры наблюдения. На нём лежит тело
## игрока: из своих глаз его быть не должно, на записи — должно.
const CAMERA_ONLY_LAYER := 1 << 9

@export var walk_speed := 2.2
@export var run_speed := 4.0
@export var mouse_sensitivity := 0.0022
## Насколько сильно камера качается при ходьбе.
@export var bob_amount := 0.035
@export var bob_speed := 9.0

@export_group("Фонарик")
## Сколько секунд горит на полном заряде.
@export var battery_seconds := 240.0
## Ниже этого остатка свет начинает мигать и желтеть.
@export var battery_warning := 0.22

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight

var battery := 1.0

var _bob_time := 0.0
var _base_height := 0.0
var _steps: AudioStreamPlayer3D
var _last_bob_phase := 0.0
var _flashlight_energy := 0.0


## Скримеры ищут игрока по группе, а не по имени узла.
func _enter_tree() -> void:
	add_to_group("player")


func _ready() -> void:
	_base_height = head.position.y
	_flashlight_energy = flashlight.light_energy
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Взаимодействие живёт отдельным узлом: контроллер отвечает
	# за движение, а что делает E — другая забота, и она будет расти.
	var interactor := Interactor.new()
	add_child(interactor)

	_build_body()

	_steps = AudioStreamPlayer3D.new()
	_steps.volume_db = -12.0
	_steps.max_distance = 8.0
	var path := "res://assets/audio/step.wav"
	if ResourceLoader.exists(path):
		_steps.stream = load(path)
	add_child(_steps)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * mouse_sensitivity)
		head.rotate_x(-motion.relative.y * mouse_sensitivity)
		# Не даём свернуть шею.
		head.rotation.x = clampf(head.rotation.x, -1.4, 1.4)

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Фонарь на отдельной кнопке: E занят взятием предметов, и мигать
	# светом при каждой попытке что-то поднять — худшее, что можно
	# сделать в тёмной игре.
	if event.is_action_pressed("stalk"):
		if battery > 0.0:
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
	_update_battery(delta)


## Заряд тратится только пока фонарь горит. У последней четверти
## свет желтеет и подрагивает — предупреждение, которое нельзя
## не заметить, но и паниковать рано.
func _update_battery(delta: float) -> void:
	if not flashlight.visible:
		return

	battery = maxf(0.0, battery - delta / battery_seconds)

	if battery <= 0.0:
		flashlight.visible = false
		return

	var energy := _flashlight_energy
	var color := Color(1.0, 0.94, 0.86)

	if battery < battery_warning:
		var t := battery / battery_warning
		# Дрожание тем заметнее, чем меньше осталось.
		var flicker := 1.0 - (1.0 - t) * 0.35 * absf(sin(Time.get_ticks_msec() * 0.011))
		energy *= lerpf(0.45, 1.0, t) * flicker
		color = color.lerp(Color(1.0, 0.72, 0.42), 1.0 - t)

	flashlight.light_energy = energy
	flashlight.light_color = color


## Тело игрока. Из своих глаз его не видно, а на камерах наблюдения —
## видно: в этом весь смысл. Разделение через слои видимости — основная
## камера просто не рисует слой, на котором лежит тело.
func _build_body() -> void:
	var path := "res://assets/models/figure.glb"
	if not ResourceLoader.exists(path):
		return

	var scene: PackedScene = load(path)
	var body := scene.instantiate()
	# Origin игрока — по центру капсулы, модель стоит от ног.
	body.position = Vector3(0.0, -0.9, 0.0)
	add_child(body)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.13, 0.05, 0.06)
	mat.roughness = 0.9

	_set_body_layer(body, mat)

	# Основная камера этот слой не видит — иначе собственное тело
	# закрывало бы весь обзор изнутри головы.
	camera.cull_mask &= ~CAMERA_ONLY_LAYER


func _set_body_layer(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		mesh.material_override = material
		mesh.layers = CAMERA_ONLY_LAYER
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in node.get_children():
		_set_body_layer(child, material)


## Полностью заряженная батарея. Пригодится точкам сохранения.
func recharge() -> void:
	battery = 1.0


## Покачивание камеры — самая дешёвая вещь, отличающая «камеру летает»
## от «человек идёт».
func _update_bob(delta: float, moving: bool) -> void:
	if moving and is_on_floor():
		_bob_time += delta * bob_speed
		var offset := sin(_bob_time) * bob_amount
		head.position.y = _base_height + offset
		# Лёгкий крен в стороны добавляет веса шагу.
		head.rotation.z = cos(_bob_time * 0.5) * 0.006

		# Шаг звучит в нижней точке качания, а не по таймеру: тогда
		# звук совпадает с тем, что видит глаз.
		var phase := sin(_bob_time)
		if _last_bob_phase > 0.0 and phase <= 0.0 and _steps.stream != null:
			_steps.pitch_scale = randf_range(0.92, 1.08)
			_steps.play()
		_last_bob_phase = phase
	else:
		_bob_time = 0.0
		head.position.y = lerpf(head.position.y, _base_height, 1.0 - exp(-8.0 * delta))
		head.rotation.z = lerpf(head.rotation.z, 0.0, 1.0 - exp(-8.0 * delta))
