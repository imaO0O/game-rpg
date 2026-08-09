## Взаимодействие взглядом: луч из камеры ищет, на что игрок смотрит.
##
## Отдельным узлом, а не в контроллере игрока: контроллер отвечает
## за движение, а что происходит от нажатия E — совсем другая забота,
## и она будет расти (осколки, двери, кофемашина, записки).
class_name Interactor
extends Node3D

signal target_changed(target: Interactable)
signal taken(id: String)
signal used(target: Interactable)

## На какой дистанции предмет ещё можно взять.
@export var reach := 2.4

var _camera: Camera3D
var _current: Interactable


func _ready() -> void:
	_camera = _find_camera(get_parent())
	if _camera == null:
		push_warning("Interactor не нашёл камеру — взаимодействие работать не будет")


func _physics_process(_delta: float) -> void:
	if _camera == null:
		return

	var found := _cast()
	if found == _current:
		return

	if _current != null and is_instance_valid(_current):
		_current.set_looked_at(false)

	_current = found

	if _current != null:
		_current.set_looked_at(true)

	target_changed.emit(_current)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if _current == null or not is_instance_valid(_current):
		return

	var target := _current
	if not target.interact():
		return

	get_viewport().set_input_as_handled()
	used.emit(target)

	# Осколок исчезает после подбора, кофемашина остаётся на месте.
	if target is MemoryObject:
		taken.emit((target as MemoryObject).id)
		_current = null
		target_changed.emit(null)


## Луч по маске осколков. Обычная геометрия его не перехватывает —
## иначе предмет на столе было бы не взять из-за самого стола.
func _cast() -> Interactable:
	var space := get_world_3d().direct_space_state
	var from := _camera.global_position
	var to := from - _camera.global_transform.basis.z * reach

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = Interactable.LAYER

	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return null

	var collider: Object = hit.get("collider")
	if collider == null:
		return null

	# Область висит внутри объекта, поэтому нужный узел — родитель.
	var node := (collider as Node).get_parent()
	return node as Interactable


func current() -> Interactable:
	return _current


func _find_camera(node: Node) -> Camera3D:
	if node == null:
		return null
	if node is Camera3D:
		return node
	for child in node.get_children():
		var found := _find_camera(child)
		if found != null:
			return found
	return null
