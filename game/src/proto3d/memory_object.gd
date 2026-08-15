## Осколок памяти в доме (CONCEPT_3D.md).
##
## Предмет, который можно взять и рассмотреть. Учёт ведёт то же
## состояние, что и в двумерной версии: идентификаторы, каталог
## и сохранение переиспользуются целиком, менялась только оболочка.
##
## Сам предмет ничего не знает о своём содержании — подпись и медиа
## приходят из каталога, а тот берёт их из private/.
class_name MemoryObject
extends Interactable

signal collected(id: String)

## Проверка перед подбором: если вернёт true, осколок не даётся в руки.
## Через неё убегающий осколок вмешивается в подбор, а сам предмет
## о нём ничего не знает. Сигналом это не сделать — сигналы в Godot
## не возвращают значений.
var escape_check: Callable

## Идентификатор в каталоге осколков.
@export var id := ""
## Модель предмета из assets/models. Пустая — простая подставка.
@export var model := ""
## Насколько сильно предмет светится, когда на него смотрят.
@export var glow := 0.55

var _highlight: OmniLight3D
var _spin := 0.0


func _ready() -> void:
	if id.is_empty():
		push_warning("Осколок без id — он не сохранится")

	# Уже собранные не появляются заново при перезаходе.
	if Game.has_shard(id):
		queue_free()
		return

	prompt_text = "взять"
	_build_visual()
	build_target(0.5, Vector3(0.0, 0.3, 0.0))

	# Слабый огонёк: в тёмном доме предмет иначе не найти вовсе,
	# а искать наощупь — не та игра.
	_highlight = OmniLight3D.new()
	_highlight.light_color = Color(1.0, 0.86, 0.62)
	_highlight.light_energy = 0.12
	_highlight.omni_range = 1.4
	_highlight.shadow_enabled = false
	_highlight.position = Vector3(0.0, 0.35, 0.0)
	add_child(_highlight)


func _process(delta: float) -> void:
	# Медленное вращение отличает то, что можно взять, от обстановки.
	_spin += delta * 0.7
	if get_child_count() > 0:
		var visual := get_child(0)
		if visual is Node3D:
			(visual as Node3D).rotation.y = _spin

	var target := glow if is_looked_at() else 0.12
	_highlight.light_energy = lerpf(_highlight.light_energy, target, 1.0 - exp(-8.0 * delta))


func _build_visual() -> void:
	if not model.is_empty():
		var path := "res://assets/models/%s.glb" % model
		if ResourceLoader.exists(path):
			var scene: PackedScene = load(path)
			var node := scene.instantiate()
			# Из Blender модели приходят без материалов намеренно.
			# Без назначения предмет рендерится тёмным кубом и читается
			# как заглушка, а не как вещь, которую хочется взять.
			_paint(node, _object_material())
			add_child(node)
			return

	# Запасной вид: рамка с фотографией. Работает, пока нет модели.
	var frame := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.16, 0.22, 0.012)
	frame.mesh = box
	frame.position = Vector3(0.0, 0.28, 0.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.74, 0.66)
	mat.roughness = 0.7
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.42, 0.3)
	mat.emission_energy_multiplier = 0.35
	frame.material_override = mat
	add_child(frame)


## Светлее окружения: осколок должен выделяться среди обстановки,
## иначе его не отличить от декорации.
func _object_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.58, 0.55, 0.5)
	mat.roughness = 0.45
	return mat


func _paint(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child in node.get_children():
		_paint(child, material)


func caption() -> String:
	return ShardRegistry.caption(id)


## Взять. Возвращает false, если осколок уже был собран
## или если он сейчас не даётся.
func interact() -> bool:
	if escape_check.is_valid() and escape_check.call():
		return false

	if not Game.collect_shard(id):
		return false
	collected.emit(id)
	queue_free()
	return true


## Прежнее имя действия — оставлено, потому что читается лучше
## обобщённого interact() там, где речь именно про осколок.
func take() -> bool:
	return interact()
