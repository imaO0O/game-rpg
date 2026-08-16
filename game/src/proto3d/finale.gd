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

## Во сколько раз быстрее идут реплики в проверках. Ждать пятнадцать
## секунд на каждом прогоне тестов — непозволительная роскошь, а сама
## последовательность от скорости не зависит.
static var speed_scale := 1.0

const TRIGGER_SIZE := Vector3(3.4, 2.4, 3.4)

var _figure: Node3D
var _memory: MemoryObject
var _backlight: OmniLight3D
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

	# Контровой свет из-за плеч: тёмный силуэт на тёмной доске
	# сливается с ней, и вместо человека читается пятно.
	# Вплотную за плечами, а не в глубине комнаты: стоя далеко,
	# источник освещал стену за спиной, а сам силуэт оставался
	# тёмным пятном на тёмной доске — то есть ровно наоборот.
	_backlight = OmniLight3D.new()
	_backlight.position = Vector3(-0.12, 1.72, -1.05)
	_backlight.light_color = Color(0.44, 0.62, 0.79)
	_backlight.light_energy = 1.6
	_backlight.omni_range = 1.9
	_backlight.omni_attenuation = 2.6
	_backlight.light_size = 0.16
	_backlight.shadow_enabled = true
	_backlight.visible = false
	add_child(_backlight)

	# Слабый заполняющий спереди: без него Зейд в кадре встречи —
	# бесформенное тёмное пятно, и вся сцена держится на голосе.
	# Тёплый, чтобы не спорить с холодным контровым.
	var fill := OmniLight3D.new()
	fill.position = Vector3(0.35, 1.5, 1.1)
	fill.light_color = Color(1.0, 0.86, 0.68)
	fill.light_energy = 0.55
	fill.omni_range = 2.6
	fill.omni_attenuation = 2.4
	fill.shadow_enabled = false
	add_child(fill)

	# Последний осколок лежит у него в руках и берётся только
	# после разговора: взять его раньше — значит пропустить сцену.
	_memory = MemoryObject.new()
	_memory.id = "zade_last"
	_memory.position = Vector3(-0.35, 0.85, 0.35)
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

	# Подсказка взаимодействия во время сцены висела бы прямо на голове
	# говорящего и поверх доски — то есть ровно на том, ради чего игрок
	# сюда шёл. Гасим её, пока он говорит.
	_set_pickable(false)
	_backlight.visible = true

	started.emit()
	_advance()


func _advance() -> void:
	_line += 1

	if _line >= LINES.size():
		_finish()
		return

	var spec: Dictionary = LINES[_line]
	_timer = spec.hold * speed_scale
	print("[финал] %s" % spec.text)


func _finish() -> void:
	_running = false
	_done = true
	_set_pickable(true)

	# Уходит: разворачивается и растворяется в темноте, а не исчезает
	# рывком. Он не призрак, он просто уходит.
	var tween := create_tween()
	tween.tween_property(_figure, "position:z", _figure.position.z - 4.0, 3.2)
	tween.parallel().tween_property(_figure, "scale", Vector3.ONE * 0.9, 3.2)

	finished.emit()


## Пока идёт разговор, осколок взять нельзя.
func _hold_until_done() -> bool:
	return not _done


## Осколок не должен даже подсвечиваться под прицелом, пока идёт сцена.
func _set_pickable(value: bool) -> void:
	if _memory == null:
		return
	for child in _memory.get_children():
		if child is Area3D:
			(child as Area3D).monitorable = value
			(child as Area3D).collision_layer = Interactable.LAYER if value else 0


func is_done() -> bool:
	return _done


func _build_zade() -> Node3D:
	# Своя модель, а не безликий силуэт скримеров: в финале он должен
	# читаться конкретным человеком, иначе встреча ничем не отличается
	# от очередной тени в коридоре.
	var path := "res://assets/models/zade.glb"
	if not ResourceLoader.exists(path):
		push_warning("Нет модели Зейда для финала")
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
