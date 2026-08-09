## Комната Зейда (CONCEPT_3D.md, комната №5).
##
## Она должна рассказать о нём без единой записки — через то, что здесь
## стоит и куда направлено. Стул повёрнут к доске, доска увешана
## фотографиями, между ними натянуты нитки. Классическая доска сталкера,
## только с обратным знаком: следят не за Катей, а Катя пришла сама.
##
## Здесь же открывается Сталк-режим: способность видеть сквозь стены
## логично достаётся в комнате того, кто всю игру подглядывал.
class_name ZadeRoom
extends Node3D

const BOARD_SIZE := Vector2(2.2, 1.5)
const PHOTO_COUNT := 14

@export var board_centre := Vector3(-4.0, 1.5, -18.3)

var _photo_material: StandardMaterial3D
var _thread_material: StandardMaterial3D
var _board_material: StandardMaterial3D


func _ready() -> void:
	_build_materials()
	_build_board()
	_build_photos()


func _build_materials() -> void:
	_board_material = StandardMaterial3D.new()
	_board_material.albedo_color = Color(0.24, 0.20, 0.16)
	_board_material.roughness = 0.9

	# Фотографии светлее всего в комнате: взгляд должен упереться в них
	# раньше, чем разберёт остальное.
	_photo_material = StandardMaterial3D.new()
	_photo_material.albedo_color = Color(0.74, 0.71, 0.66)
	_photo_material.roughness = 0.65
	_photo_material.emission_enabled = true
	_photo_material.emission = Color(0.4, 0.38, 0.34)
	_photo_material.emission_energy_multiplier = 0.18

	# Нитки красные — единственный цвет в доме (CONCEPT_3D.md, «Тон»).
	_thread_material = StandardMaterial3D.new()
	_thread_material.albedo_color = Color(0.62, 0.06, 0.05)
	_thread_material.roughness = 0.8


func _build_board() -> void:
	var board := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(BOARD_SIZE.x, BOARD_SIZE.y, 0.04)
	board.mesh = box
	board.position = board_centre
	board.material_override = _board_material
	add_child(board)


## Фотографии и нитки между ними. Расположение псевдослучайное, но
## устойчивое: одна и та же доска при каждом запуске, иначе комната
## перестаёт быть чьей-то и становится генератором.
func _build_photos() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260809

	var points: Array[Vector3] = []

	for i in PHOTO_COUNT:
		var x := rng.randf_range(-BOARD_SIZE.x * 0.42, BOARD_SIZE.x * 0.42)
		var y := rng.randf_range(-BOARD_SIZE.y * 0.38, BOARD_SIZE.y * 0.38)
		# Ближе к зрителю, а не вглубь: доска стоит у дальней стены,
		# и смещение в минус прятало фотографии за неё.
		var pos := board_centre + Vector3(x, y, 0.035)
		points.append(pos)

		var photo := MeshInstance3D.new()
		var quad := BoxMesh.new()
		# Разный формат: одинаковые прямоугольники читаются как плитка.
		var w := rng.randf_range(0.12, 0.2)
		quad.size = Vector3(w, w * rng.randf_range(1.1, 1.5), 0.006)
		photo.mesh = quad
		photo.position = pos
		photo.rotation.z = rng.randf_range(-0.14, 0.14)
		photo.material_override = _photo_material
		add_child(photo)

	# Нитки соединяют не все пары, а цепочкой с несколькими перемычками:
	# сплошная сетка выглядит как декорация, цепочка — как мысль.
	for i in range(points.size() - 1):
		_thread(points[i], points[i + 1])
	for i in range(0, points.size() - 4, 4):
		_thread(points[i], points[i + 3])


func _thread(from: Vector3, to: Vector3) -> void:
	var mid := (from + to) * 0.5
	var length := from.distance_to(to)
	if length < 0.01:
		return

	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0035
	mesh.bottom_radius = 0.0035
	mesh.height = length
	mesh.radial_segments = 5

	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _thread_material
	node.position = mid
	# Цилиндр смотрит вдоль своей Y, поэтому разворачиваем его по нитке.
	node.look_at_from_position(mid, to, Vector3.UP)
	node.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	add_child(node)
