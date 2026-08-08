## Снимки 3D-прототипа.
##
## Ставит камеру в несколько точек дома и сохраняет кадры — чтобы
## оценивать картинку, не проходя сцену руками.
extends Node

const HOUSE := preload("res://src/proto3d/house3d.tscn")
const OUT_DIR := "user://shots3d"

## Точка съёмки: где стоит игрок и куда смотрит.
const VIEWS := [
	{"name": "a_room", "pos": Vector3(-1.2, 0.9, 1.2), "yaw": -0.6, "pitch": -0.05},
	{"name": "b_table", "pos": Vector3(0.2, 0.9, 1.5), "yaw": -0.9, "pitch": -0.15},
	{"name": "c_corridor", "pos": Vector3(0.0, 0.9, -2.6), "yaw": 0.0, "pitch": -0.02},
	{"name": "d_deep", "pos": Vector3(0.0, 0.9, -7.5), "yaw": 0.15, "pitch": -0.05},
	{"name": "e_side", "pos": Vector3(3.0, 0.9, -11.0), "yaw": 1.4, "pitch": -0.05},
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
