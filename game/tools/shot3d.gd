## Снимки 3D-прототипа.
##
## Ставит камеру в несколько точек дома и сохраняет кадры — чтобы
## оценивать картинку, не проходя сцену руками.
extends Node

const HOUSE := preload("res://src/proto3d/house3d.tscn")
const OUT_DIR := "user://shots3d"

## Точка съёмки: где стоит игрок и куда смотрит.
## Направления подобраны так, чтобы в кадр попадала мебель, а не голая стена.
const VIEWS := [
	{"name": "a_table", "pos": Vector3(-1.1, 0.9, 1.5), "yaw": -1.15, "pitch": -0.12},
	{"name": "b_wardrobe", "pos": Vector3(0.4, 0.9, 0.8), "yaw": 0.87, "pitch": -0.05},
	{"name": "c_door", "pos": Vector3(0.0, 0.9, -0.4), "yaw": 0.0, "pitch": -0.03},
	{"name": "d_corridor", "pos": Vector3(0.0, 0.9, -4.2), "yaw": 0.0, "pitch": -0.02},
	{"name": "e_boxes", "pos": Vector3(0.6, 0.9, -7.4), "yaw": 0.35, "pitch": -0.12},
	{"name": "f_far_room", "pos": Vector3(3.2, 0.9, -10.4), "yaw": 1.25, "pitch": -0.04},
	# Комната Зейда: кадр от двери, чтобы в него попали и стул, и доска.
	{"name": "g_zade", "pos": Vector3(-4.0, 0.9, -14.6), "yaw": 0.0, "pitch": -0.02},
	{"name": "h_board", "pos": Vector3(-4.0, 1.4, -17.0), "yaw": 0.0, "pitch": 0.02},
]

var _level: Node3D
var _player: CharacterBody3D
var _head: Node3D


func _ready() -> void:
	_level = HOUSE.instantiate()
	add_child(_level)
	_player = _level.get_node("Player")
	_head = _player.get_node("Head")
	# Мышь в снимках не нужна, а захват курсора мешает.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	# Глобальному освещению и туману нужно несколько кадров, чтобы сойтись.
	for i in 90:
		await get_tree().process_frame

	for view: Dictionary in VIEWS:
		await _capture(view)

	print("папка: ", ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit(0)


func _capture(view: Dictionary) -> void:
	_player.global_position = view.pos
	_player.rotation.y = view.yaw
	_head.rotation.x = view.pitch

	for i in 40:
		await get_tree().process_frame

	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, view.name]
	if image.save_png(path) == OK:
		print("снято: ", view.name)
	else:
		push_error("Не удалось сохранить %s" % path)
