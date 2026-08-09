## Интерфейс дома.
##
## Хоррор не терпит панелей: всё, что можно убрать, убрано. Остаются
## три вещи, без которых игрок не понимает, что происходит, —
## куда он смотрит, что можно взять и сколько осталось света.
##
## Заряд показывается только когда садится: полная батарея в кадре
## ничего не сообщает и лишь занимает угол.
extends CanvasLayer

const CROSSHAIR_SIZE := 5.0
const BATTERY_SHOW_BELOW := 0.35

@export var player: CharacterBody3D

@onready var _prompt: Label = $Root/Prompt
@onready var _shards: Label = $Root/Shards
@onready var _battery: Label = $Root/Battery
@onready var _crosshair: Control = $Root/Crosshair

var _interactor: Interactor
var _toast_time := 0.0


func _ready() -> void:
	if player != null:
		for child in player.get_children():
			if child is Interactor:
				_interactor = child

	if _interactor != null:
		_interactor.target_changed.connect(_on_target_changed)
		_interactor.taken.connect(_on_taken)

	_crosshair.draw.connect(_draw_crosshair)
	_prompt.text = ""
	_update_shards()


func _process(delta: float) -> void:
	_update_battery()

	if _toast_time > 0.0:
		_toast_time = maxf(0.0, _toast_time - delta)
		if _toast_time <= 0.0 and _interactor != null and _interactor.current() == null:
			_prompt.text = ""


## Точка в центре: без неё непонятно, куда именно смотришь,
## а прицеливаться в тёмной комнате приходится точно.
func _draw_crosshair() -> void:
	var centre := _crosshair.size * 0.5
	var active := _interactor != null and _interactor.current() != null

	var color := Color(1.0, 0.9, 0.7, 0.85) if active else Color(1.0, 1.0, 1.0, 0.28)
	var radius := CROSSHAIR_SIZE * (1.6 if active else 1.0)
	_crosshair.draw_circle(centre, radius, color, false, 1.5, true)


func _on_target_changed(target: Interactable) -> void:
	_crosshair.queue_redraw()

	if target == null:
		if _toast_time <= 0.0:
			_prompt.text = ""
		return

	# Подпись даёт сам объект: осколок предлагает взять, кофемашина —
	# выпить конкретный напиток.
	_prompt.text = "E — %s" % target.prompt()
	_toast_time = 0.0


func _on_taken(id: String) -> void:
	_update_shards()
	# Показываем не «+1», а что именно нашлось: смысл собирания
	# в содержании осколка, а не в счётчике.
	_prompt.text = ShardRegistry.caption(id)
	_toast_time = 2.6
	_crosshair.queue_redraw()


func _update_shards() -> void:
	_shards.text = "%d / %d" % [Game.shard_count(), ShardRegistry.total()]


func _update_battery() -> void:
	if player == null or not ("battery" in player):
		_battery.text = ""
		return

	var charge: float = player.battery
	if charge >= BATTERY_SHOW_BELOW:
		_battery.text = ""
		return

	_battery.text = "фонарь: %d%%" % int(charge * 100.0)
	# Краснеет по мере того, как садится.
	_battery.modulate = Color(1.0, 1.0, 1.0).lerp(
		Color(1.0, 0.45, 0.3),
		1.0 - charge / BATTERY_SHOW_BELOW
	)
