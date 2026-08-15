## Финал: встреча с Зейдом (CONCEPT_3D.md, «Финал»).
##
## Он не нападает. Он всё это время готовился к встрече и страшно
## нервничает: отдаёт последний осколок, извиняется за скример
## в коридоре и уходит, потому что дом был не его.
##
## Единственная сцена в игре, где что-то происходит само. Поэтому
## управление у игрока не отбирается: он может уйти, не дослушав,
## и это тоже ответ.
class_name Finale
extends Area3D

signal started
signal finished

## Реплики и паузы после каждой. Паузы разной длины: ровный ритм
## звучал бы как автоответчик, а он должен запинаться.
const LINES := [
	{"text": "Зейд: ...здравствуй.", "hold": 1.8},
	{"text": "Зейд: я знал, что ты придёшь. я готовился.", "hold": 2.4},
	{"text": "Зейд: не так готовился. я имею в виду — прибрался.", "hold": 2.6},
	{"text": "Зейд: прости за колесо. это было глупо.", "hold": 2.2},
	{"text": "Зейд: вот. последнее. оно всегда было твоим.", "hold": 2.8},
	{"text": "Зейд: дом был не мой. я просто... смотрел.", "hold": 3.0},
]

const TRIGGER_SIZE := Vector3(3.4, 2.4, 3.4)

var _figure: Node3D
var _memory: MemoryObject
var _line := -1
var _timer := 0.0
var _running := false
var _done := false


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = TRIGGER_SIZE
	shape.shape = box
	add_child(shape)

	body_entered.connect(_on_body_entered)

	_figure = _build_zade()
	add_child(_figure)

	# Последний осколок лежит у него в руках и берётся только
	# после разговора: взять его раньше — значит пропустить сцену.
	_memory = MemoryObject.new()
	_memory.id = "zade_last"
	_memory.position = Vector3(0.0, 0.85, 0.35)
	_memory.escape_check = _hold_until_done
	add_child(_memory)


func _process(delta: float) -> void:
	if not _running:
		return

	_timer = maxf(0.0, _timer - delta)
	if _timer > 0.0:
		return

	_advance()


func _on_body_entered(body: Node3D) -> void:
	if _running or _done or not body.is_in_group("player"):
		return
	if Game.has_flag("finale"):
		return

	Game.set_flag("finale")
	_running = true
	started.emit()
	_advance()


func _advance() -> void:
	_line += 1

	if _line >= LINES.size():
		_finish()
		return

	var spec: Dictionary = LINES[_line]
	_timer = spec.hold
	print("[финал] %s" % spec.text)


func _finish() -> void:
	_running = false
	_done = true

	# Уходит: разворачивается и растворяется в темноте, а не исчезает
	# рывком. Он не призрак, он просто уходит.
	var tween := create_tween()
	tween.tween_property(_figure, "position:z", _figure.position.z - 4.0, 3.2)
	tween.parallel().tween_property(_figure, "scale", Vector3.ONE * 0.9, 3.2)

	finished.emit()


## Пока идёт разговор, осколок взять нельзя.
func _hold_until_done() -> bool:
	return not _done


func is_done() -> bool:
	return _done


func _build_zade() -> Node3D:
	var path := "res://assets/models/figure.glb"
	if not ResourceLoader.exists(path):
		push_warning("Нет модели фигуры для финала")
		return Node3D.new()

	var scene: PackedScene = load(path)
	var node := scene.instantiate()
	node.position = Vector3(0.0, 0.0, -0.6)

	# Не чёрный силуэт, как в скримерах: здесь он наконец человек,
	# а не тень на записи.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.2, 0.21)
	mat.roughness = 0.85
	_paint(node, mat)

	return node


func _paint(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child in node.get_children():
		_paint(child, material)
