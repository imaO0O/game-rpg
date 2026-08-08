## Снимает комнаты целиком и сохраняет PNG в user://shots/.
##
## Нужен, чтобы смотреть на планировку, не проходя её руками: видно сразу,
## где дыра в полу, куда не допрыгнуть и что загорожено.
##
## Запуск (без --headless, нужен реальный рендер):
##   godot --path game res://tools/screenshot.tscn
extends Node

const OUT_DIR := "user://shots"

const SCENES := [
	{"name": "01_ryazan_home", "path": "res://src/levels/ryazan/home.tscn"},
	{"name": "02_ryazan_yard", "path": "res://src/levels/ryazan/yard.tscn"},
	{"name": "03_ryazan_park", "path": "res://src/levels/ryazan/park.tscn"},
	{"name": "04_ryazan_cellar", "path": "res://src/levels/ryazan/cellar.tscn"},
	{"name": "05_lair", "path": "res://src/levels/lair.tscn"},
	{"name": "06_testbed", "path": "res://src/levels/testbed.tscn"},
]


func _ready() -> void:
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	Game.reset()

	for shot: Dictionary in SCENES:
		# Логово имеет смысл снимать только с чем-то собранным — но
		# собирать до съёмки комнат нельзя, иначе осколки в них не появятся.
		if shot.name.ends_with("lair"):
			_fill_state_for_lair()
		await _capture(shot)

	print("папка: ", ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit(0)


func _fill_state_for_lair() -> void:
	Game.collect_shard("ryazan_01")
	Game.collect_shard("ryazan_03")
	Game.register_stop("ryazan_yard", {"city": "Рязань", "drink": "капучино"})


func _capture(shot: Dictionary) -> void:
	var scene: PackedScene = load(shot.path)
	var level := scene.instantiate()
	add_child(level)

	# Даём комнате построиться и физике поставить игрока на пол.
	for i in 25:
		await get_tree().process_frame

	_frame_whole_room(level)

	for i in 10:
		await get_tree().process_frame

	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, shot.name]
	if image.save_png(path) == OK:
		print("снято: ", shot.name)
	else:
		push_error("Не удалось сохранить %s" % path)

	level.queue_free()
	await get_tree().process_frame


## Отводим камеру так, чтобы комната влезла в кадр целиком.
func _frame_whole_room(level: Node) -> void:
	var camera := level.get_node_or_null("Camera") as GameCamera
	var area := Rect2(Vector2.ZERO, Vector2(1024.0, 640.0))

	if camera == null:
		# Room создаёт камеру сам, без имени узла в сцене.
		for child in level.get_children():
			if child is GameCamera:
				camera = child
				break

	if camera == null:
		return

	if level is Room:
		area = (level as Room).world_bounds()

	# target отключаем: иначе камера тут же уедет обратно к игроку,
	# а зум вернётся к единице.
	camera.target = null
	camera.limit_left = -100000
	camera.limit_top = -100000
	camera.limit_right = 100000
	camera.limit_bottom = 100000
	camera.global_position = area.get_center()
	camera.offset = Vector2.ZERO

	var fit := minf(640.0 / area.size.x, 360.0 / area.size.y) * 0.96
	camera.zoom = Vector2(fit, fit)
