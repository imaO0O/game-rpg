## Снимает полигон в нескольких точках и сохраняет PNG в user://shots/.
##
## Нужен, чтобы смотреть на игру, не запуская её руками каждый раз:
## правка палитры или размеров проверяется одним прогоном.
##
## Запуск (без --headless, нужен реальный рендер):
##   godot --path game res://tools/screenshot.tscn
extends Node

const TESTBED := preload("res://src/levels/testbed.tscn")
const OUT_DIR := "user://shots"

## Куда смотреть и как это назвать.
const SHOTS := [
	{"name": "01_start", "x": 96.0, "note": "старт и кофейня"},
	{"name": "02_ladder", "x": 560.0, "note": "лестница платформ"},
	{"name": "03_gaps", "x": 1400.0, "note": "пропасти"},
	{"name": "04_water", "x": 2270.0, "note": "вода"},
	{"name": "05_door", "x": 2530.0, "note": "змеиная дверь"},
	{"name": "06_pocket", "x": 2830.0, "note": "скрытая стена и карман"},
]

var _player: Player
var _camera: GameCamera


func _ready() -> void:
	var level := TESTBED.instantiate()
	add_child(level)
	_player = level.get_node("Player")
	_camera = level.get_node("Camera")
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	# Дать уровню построиться и физике встать на место.
	for i in 20:
		await get_tree().process_frame

	# Способности нужны, чтобы гейты было видно в открытом состоянии тоже.
	Game.unlock(Abilities.Kind.SLIPSTREAM)

	for shot: Dictionary in SHOTS:
		await _capture(shot)

	print("папка: ", ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit(0)


func _capture(shot: Dictionary) -> void:
	_player.respawn_at(Vector2(shot.x, 320.0))
	_camera.global_position = _player.global_position

	# Камера сглаживает движение — даём ей доехать и объектам отрисоваться.
	for i in 30:
		await get_tree().process_frame

	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, shot.name]
	if image.save_png(path) != OK:
		push_error("Не удалось сохранить %s" % path)
		return
	print("снято: %s — %s" % [shot.name, shot.note])
