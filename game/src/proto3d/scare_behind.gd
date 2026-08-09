## Скример «За спиной» (CONCEPT_3D.md).
##
## Игрок переключает камеру на ту, что снимает его же комнату, и видит
## себя со спины. Через секунду за его спиной на записи появляется
## вторая фигура. В самой комнате при этом никого нет — обернувшись,
## игрок не увидит ничего.
##
## Это самый неприятный из скримеров именно потому, что не даёт
## проверить. Поэтому и разрядка мягче всех: Пинки списывает всё
## на качество записи, и остаётся неясным, кто прав.
extends Scare

const PUNCHLINE := "Пинки: у камеры просто шумы. я почти уверена."
const APPEAR_DELAY := 1.1
## Подпись камеры, на которой срабатывает. Держать в согласии
## с house3d: расхождение здесь ломает скример молча.
const TARGET_CAMERA := "эта комната"

var _figure: Node3D
var _monitor: CameraMonitor
## Не _player: так называется поле базового класса, а повторное
## объявление GDScript не компилирует — молча, без сообщения в игре.
var _victim: Node3D
var _pending := 0.0


func _ready() -> void:
	id = "behind"
	trigger_size = Vector3.ZERO
	strike_time = 3.4
	super._ready()

	_figure = _build_figure()
	_figure.visible = false
	add_child(_figure)


func attach(monitor: CameraMonitor) -> void:
	_monitor = monitor
	if _monitor == null:
		push_warning("Скример «за спиной» не получил монитор")
		return
	_monitor.switched.connect(_on_switched)


func _process(delta: float) -> void:
	if _pending <= 0.0:
		return

	_pending = maxf(0.0, _pending - delta)
	if _pending > 0.0:
		return

	_place_behind_player()
	_figure.visible = true
	if _monitor != null:
		_monitor.glitch_now(0.7)


func _on_switched(camera: SecurityCamera) -> void:
	if camera.label != TARGET_CAMERA:
		return
	fire()


func _strike() -> void:
	_victim = _find_player()
	if _victim == null:
		return
	# Появляется не сразу: сначала игрок должен узнать себя на записи
	# и решить, что понял, на что смотрит.
	_pending = APPEAR_DELAY


func _resolve() -> void:
	_figure.visible = false
	_pending = 0.0
	if _monitor != null:
		_monitor.glitch_now(0.5)
	print("[%s]" % PUNCHLINE)


## Ставим фигуру за спиной игрока и лицом к нему.
func _place_behind_player() -> void:
	if _victim == null:
		return

	var back := _victim.global_transform.basis.z.normalized()
	var spot := _victim.global_position + back * 1.5
	spot.y = _victim.global_position.y - 0.9

	_figure.global_position = spot
	_figure.look_at(_victim.global_position, Vector3.UP)


func _find_player() -> Node3D:
	for node in get_tree().get_nodes_in_group("player"):
		if node is Node3D:
			return node
	return null


func _build_figure() -> Node3D:
	var path := "res://assets/models/figure.glb"
	if not ResourceLoader.exists(path):
		push_warning("Нет модели фигуры")
		return Node3D.new()

	var scene: PackedScene = load(path)
	var node := scene.instantiate()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.03, 0.03, 0.035)
	mat.roughness = 0.98
	_apply(node, mat)

	return node


func _apply(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child in node.get_children():
		_apply(child, material)
