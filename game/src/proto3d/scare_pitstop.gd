## Скример «BOX BOX BOX» (CONCEPT_3D.md, скример №1).
##
## Свет гаснет, из темноты орёт радио пит-волла, в кадр влетает колесо.
## Разрядка: механик замечает, что машина не та, забирает колесо и уходит.
##
## Это первый скример в игре, поэтому он должен научить правилам жанра:
## после него игрок обязан понять, что пугать будут часто, но больно
## не сделают ни разу.
extends Scare

const WHEEL_SPEED := 7.0
const RADIO_LINE := "BOX BOX BOX!"
const PUNCHLINE := "...извини. Не та машина."

var _wheel: Node3D
var _wheel_target := Vector3.ZERO
var _rolling := false


func _ready() -> void:
	id = "pitstop"
	trigger_size = Vector3(3.0, 2.4, 2.5)
	strike_time = 1.4
	super._ready()

	_wheel = _build_wheel()
	_wheel.visible = false
	add_child(_wheel)


func _process(delta: float) -> void:
	if not _rolling:
		return
	# Колесо катится мимо игрока и вращается вокруг своей оси.
	_wheel.global_position = _wheel.global_position.move_toward(_wheel_target, WHEEL_SPEED * delta)
	_wheel.rotate_z(-delta * 9.0)
	if _wheel.global_position.distance_to(_wheel_target) < 0.05:
		_rolling = false


func _strike() -> void:
	# Темнота на треть секунды: глаз не успевает разобрать, что произошло.
	blackout(0.35)

	_wheel.global_position = global_position + Vector3(-3.5, 0.34, 0.0)
	_wheel_target = global_position + Vector3(3.5, 0.34, 0.0)
	_wheel.visible = true
	_rolling = true

	_say(RADIO_LINE)


func _resolve() -> void:
	_say(PUNCHLINE)
	# Колесо укатывается совсем, чтобы не осталось лежать в коридоре.
	await get_tree().create_timer(1.6).timeout
	if is_instance_valid(_wheel):
		_wheel.visible = false


## Пока нет диалогового слоя в 3D — реплики идут в вывод.
## Заменится на Dialogic, когда появятся озвученные строки.
func _say(line: String) -> void:
	print("[пит-волл] %s" % line)


func _build_wheel() -> Node3D:
	var pivot := Node3D.new()

	var tyre := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.2
	torus.outer_radius = 0.34
	torus.rings = 20
	tyre.mesh = torus

	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.06, 0.06, 0.07)
	rubber.roughness = 0.95
	tyre.material_override = rubber
	pivot.add_child(tyre)

	# Красный диск: колесо должно читаться как ferrari-шное, а не любое.
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.2
	cyl.height = 0.16
	cyl.radial_segments = 20
	disc.mesh = cyl
	disc.rotation.x = PI * 0.5

	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.72, 0.04, 0.03)
	paint.roughness = 0.25
	paint.metallic = 0.4
	disc.material_override = paint
	pivot.add_child(disc)

	return pivot
