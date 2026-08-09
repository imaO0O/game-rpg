## Скример «Фигура на записи» (CONCEPT_3D.md).
##
## Переключаешь камеру — в дальней комнате кто-то стоит. Переключаешь
## дальше и возвращаешься — никого. Пугает здесь не движение, а его
## отсутствие: фигура не бросается, не приближается, ничего не делает.
##
## Разрядка мягкая — Пинки делает вид, что тоже видела, но не уверена.
## Прямая шутка убила бы приём: он должен оставить сомнение.
extends Scare

const PUNCHLINE := "Пинки: ...это была вешалка. наверное."
## Через сколько переключений сработает. Первое — слишком рано,
## игрок ещё разбирается, что вообще делает монитор.
const AFTER_SWITCHES := 2

var _figure: Node3D
var _monitor: CameraMonitor
var _switch_count := 0
var _visible_time := 0.0


func _ready() -> void:
	id = "camera_figure"
	trigger_size = Vector3.ZERO
	strike_time = 2.2
	super._ready()

	_figure = _build_figure()
	_figure.visible = false
	add_child(_figure)


## Привязка к монитору. Ставится до добавления в дерево.
func attach(monitor: CameraMonitor) -> void:
	_monitor = monitor
	if _monitor != null:
		_monitor.switched.connect(_on_switched)


func _process(delta: float) -> void:
	if _visible_time <= 0.0:
		return

	_visible_time = maxf(0.0, _visible_time - delta)

	# Фигура чуть покачивается — ровно настолько, чтобы нельзя было
	# решить, показалось или нет.
	if _figure.visible:
		_figure.position.x += sin(Time.get_ticks_msec() * 0.0011) * delta * 0.05

	if _visible_time <= 0.0:
		_figure.visible = false


func _on_switched(camera: SecurityCamera) -> void:
	_switch_count += 1
	if _switch_count < AFTER_SWITCHES:
		return
	# Появляется только в дальней комнате: в коридоре игрок оказался бы
	# рядом и разглядел бы подделку.
	if camera.label != "дальняя комната":
		return
	fire()


func _strike() -> void:
	# Ставим фигуру в глубину кадра, спиной к камере.
	_figure.global_position = Vector3(4.2, 0.0, -12.6)
	_figure.rotation.y = PI * 0.15
	_figure.visible = true
	_visible_time = strike_time

	# Сбой сигнала ровно в момент появления: запись «дёргается»,
	# и непонятно, фигура была до сбоя или после.
	if _monitor != null:
		_monitor.glitch_now(0.9)


func _resolve() -> void:
	_figure.visible = false
	_visible_time = 0.0

	if _monitor != null:
		_monitor.glitch_now(0.4)

	print("[%s]" % PUNCHLINE)


func _build_figure() -> Node3D:
	var path := "res://assets/models/figure.glb"
	if not ResourceLoader.exists(path):
		push_warning("Нет модели фигуры")
		return Node3D.new()

	var scene: PackedScene = load(path)
	var node := scene.instantiate()

	# Почти чёрный силуэт: на записи он и должен быть пятном,
	# а не человеком с различимыми чертами.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.045, 0.045, 0.05)
	mat.roughness = 0.95
	_apply(node, mat)

	return node


func _apply(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child in node.get_children():
		_apply(child, material)
