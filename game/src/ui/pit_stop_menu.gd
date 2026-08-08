## Меню пит-стопа — быстрое перемещение между кофейнями (DESIGN.md §6).
##
## Способность, которая ничего не добавляет в мир, но убирает из него
## скуку: после Москвы дорога назад перестаёт занимать время.
extends CanvasLayer

signal travel_selected(stop: Dictionary)
signal closed

@onready var _list: VBoxContainer = $Root/Panel/Margin/Box/List
@onready var _title: Label = $Root/Panel/Margin/Box/Title

var _stops: Array = []
var _index := 0


func _ready() -> void:
	# Меню живёт на паузе — иначе игрок продолжит бежать, пока выбирает.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()


func open(stops: Array) -> void:
	_stops = stops
	_index = 0
	_rebuild()
	show()
	get_tree().paused = true


func close() -> void:
	get_tree().paused = false
	hide()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("ui_down"):
		_move(1)
	elif event.is_action_pressed("ui_up"):
		_move(-1)
	elif event.is_action_pressed("ui_accept"):
		_confirm()
	else:
		return

	get_viewport().set_input_as_handled()


func _move(delta: int) -> void:
	if _stops.is_empty():
		return
	_index = wrapi(_index + delta, 0, _stops.size())
	_refresh_highlight()


func _confirm() -> void:
	if _stops.is_empty():
		close()
		return
	var stop: Dictionary = _stops[_index]
	get_tree().paused = false
	travel_selected.emit(stop)
	hide()
	queue_free()


func _rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()

	_title.text = "Куда едем?"

	for stop: Dictionary in _stops:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 11)
		label.text = "%s — %s" % [
			String(stop.get("city", "?")),
			String(stop.get("drink", "кофе")),
		]
		_list.add_child(label)

	_refresh_highlight()


func _refresh_highlight() -> void:
	for i in _list.get_child_count():
		var label := _list.get_child(i) as Label
		var selected := i == _index
		label.modulate = Palette.FERRARI if selected else Palette.SILVER_DIM
		label.text = ("> " if selected else "  ") + label.text.trim_prefix("> ").trim_prefix("  ")
