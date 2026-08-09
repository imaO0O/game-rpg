## Скример «Змея в шкафу» (CONCEPT_3D.md, скример №3).
##
## Из шкафа что-то падает и шипит. Через секунду выясняется, что это
## змея, и она здесь по-свойски: Слизерин — часть характера хозяйки,
## поэтому змеи в доме не враги.
##
## Разрядка отличается от остальных тем, что меняет отношение игрока
## к целому классу объектов: после неё змей в доме перестают бояться.
extends Scare

const HISS_LINE := "Ссссс!"
const PUNCHLINE := "Ссссвоя. Проходи."
const FALL_TIME := 0.55

var _snake: Node3D
var _hit_sound: AudioStreamPlayer3D
var _creak_sound: AudioStreamPlayer3D
var _fall_from := Vector3.ZERO
var _fall_to := Vector3.ZERO
var _falling := 0.0


func _ready() -> void:
	id = "snake"
	trigger_size = Vector3(2.2, 2.2, 2.2)
	strike_time = 1.5
	super._ready()

	_snake = _build_snake()
	_snake.visible = false
	add_child(_snake)

	_hit_sound = _sound("scare_hit", -6.0)
	_creak_sound = _sound("door_creak", -4.0)
	add_child(_hit_sound)
	add_child(_creak_sound)


func _process(delta: float) -> void:
	if _falling <= 0.0:
		return

	_falling = maxf(0.0, _falling - delta)
	var t := 1.0 - _falling / FALL_TIME

	# Падение с ускорением и лёгким отскоком в конце — иначе змея
	# выглядит опускающейся на верёвке.
	var eased := t * t
	if t > 0.82:
		eased = 1.0 + sin((t - 0.82) / 0.18 * PI) * 0.06

	_snake.global_position = _fall_from.lerp(_fall_to, eased)
	_snake.rotation.z = lerpf(0.9, 0.0, t)


func _strike() -> void:
	# Скрип дверцы идёт первым, удар — в момент падения.
	_creak_sound.play()
	blackout(0.22)

	_fall_from = global_position + Vector3(0.0, 0.7, 0.0)
	_fall_to = global_position + Vector3(0.0, -0.85, 0.35)
	_snake.global_position = _fall_from
	_snake.visible = true
	_falling = FALL_TIME

	_hit_sound.play()
	print("[змея] %s" % HISS_LINE)


func _resolve() -> void:
	print("[змея] %s" % PUNCHLINE)

	# Уползает под шкаф: змея должна уйти сама, а не исчезнуть.
	var tween := create_tween()
	tween.tween_property(_snake, "position", _snake.position + Vector3(-1.6, 0.0, 0.0), 1.8)
	tween.parallel().tween_property(_snake, "rotation:y", -PI * 0.35, 0.6)
	await tween.finished

	if is_instance_valid(_snake):
		_snake.visible = false


func _build_snake() -> Node3D:
	var path := "res://assets/models/snake.glb"
	if not ResourceLoader.exists(path):
		push_warning("Нет модели змеи")
		return Node3D.new()

	var scene: PackedScene = load(path)
	var node := scene.instantiate()

	# Слизеринская зелень с влажным блеском.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.13, 0.28, 0.19)
	mat.roughness = 0.35
	mat.metallic = 0.05
	_apply(node, mat)

	return node


func _apply(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child in node.get_children():
		_apply(child, material)
