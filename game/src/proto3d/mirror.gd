## Настоящее зеркало с управляемой задержкой отражения.
##
## Отражение рисуется отдельной камерой в SubViewport: её положение —
## зеркальное отражение камеры игрока относительно плоскости стекла.
## Так работают зеркала в играх вообще; здесь добавлено одно —
## история положений, из которой можно брать не последнее, а то,
## что было долю секунды назад (CONCEPT_3D.md, скример №7).
##
## Пока задержка нулевая, зеркало ведёт себя как обычное. Стоит
## поставить delay — и отражение начинает отставать. Больше ничего
## не происходит, и это самое неприятное, что может сделать зеркало.
class_name Mirror
extends Node3D

## Размер стекла в метрах.
@export var glass_size := Vector2(0.52, 1.14)
## На сколько секунд отражение отстаёт от оригинала.
@export var delay := 0.0
@export var resolution := Vector2i(512, 1024)

var _viewport: SubViewport
var _camera: Camera3D
var _surface: MeshInstance3D
var _player_camera: Camera3D
## Кольцо из недавних положений камеры игрока.
var _history: Array[Transform3D] = []
var _times: Array[float] = []
var _clock := 0.0


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = resolution
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Зеркало показывает ту же сцену, поэтому мир берём у родителя.
	_viewport.world_3d = get_viewport().world_3d
	add_child(_viewport)

	_camera = Camera3D.new()
	_camera.current = true
	_viewport.add_child(_camera)

	_surface = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = glass_size
	_surface.mesh = quad

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _viewport.get_texture()
	# Стекло не идеальное: лёгкая муть и тёплый оттенок старого амальгама.
	mat.albedo_color = Color(0.86, 0.87, 0.88)
	_surface.material_override = mat
	add_child(_surface)


func _process(delta: float) -> void:
	_clock += delta

	if _player_camera == null:
		_player_camera = _find_player_camera()
		if _player_camera == null:
			return

	_remember(_player_camera.global_transform)
	_camera.global_transform = _reflect(_sample())
	_camera.fov = _player_camera.fov


## Плоскость зеркала: начало — в центре стекла, нормаль — вдоль -Z узла.
func _reflect(source: Transform3D) -> Transform3D:
	var origin := global_position
	var normal := -global_transform.basis.z.normalized()

	var to_source := source.origin - origin
	var mirrored_origin := source.origin - 2.0 * normal * to_source.dot(normal)

	# Отражаем и оси, иначе отражение окажется вывернутым наизнанку.
	var basis := source.basis
	var x := basis.x - 2.0 * normal * basis.x.dot(normal)
	var y := basis.y - 2.0 * normal * basis.y.dot(normal)
	var z := basis.z - 2.0 * normal * basis.z.dot(normal)

	return Transform3D(Basis(-x, y, -z).orthonormalized(), mirrored_origin)


func _remember(transform: Transform3D) -> void:
	_history.append(transform)
	_times.append(_clock)

	# Держим ровно столько, сколько нужно самой большой задержке.
	while _times.size() > 2 and _clock - _times[0] > maxf(delay, 0.0) + 0.2:
		_history.remove_at(0)
		_times.remove_at(0)


## Положение, которое было `delay` секунд назад.
func _sample() -> Transform3D:
	if delay <= 0.0 or _history.size() < 2:
		return _history[-1]

	var target := _clock - delay
	for i in range(_history.size() - 1, -1, -1):
		if _times[i] <= target:
			return _history[i]
	return _history[0]


func _find_player_camera() -> Camera3D:
	for node in get_tree().get_nodes_in_group("player"):
		var found := _first_camera(node)
		if found != null:
			return found
	return null


func _first_camera(node: Node) -> Camera3D:
	if node is Camera3D:
		return node
	for child in node.get_children():
		var found := _first_camera(child)
		if found != null:
			return found
	return null
