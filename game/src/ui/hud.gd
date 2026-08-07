## Игровой интерфейс — приборная панель болида (DESIGN.md §12 задачи).
##
## Показывает ровно три вещи, которые игрок должен читать в движении:
## сколько топлива, насколько разогнан, доступен ли DRS. Всё остальное —
## всплывающие сообщения о событиях.
extends CanvasLayer

const BAR_WIDTH := 120.0
const TOAST_TIME := 2.8
const TOAST_FADE := 0.6

@export var player: Player

@onready var _caffeine_fill: ColorRect = $Root/CaffeineFill
@onready var _momentum_fill: ColorRect = $Root/MomentumFill
@onready var _drs: Label = $Root/Drs
@onready var _shards: Label = $Root/Shards
@onready var _toast: Label = $Root/Toast
@onready var _toast_hint: Label = $Root/ToastHint

var _toast_time := 0.0


func _ready() -> void:
	Game.ability_unlocked.connect(_on_ability_unlocked)
	Game.shard_collected.connect(_on_shard_collected)
	Game.game_saved.connect(_on_game_saved)

	_caffeine_fill.color = Palette.COFFEE
	_momentum_fill.color = Palette.FERRARI
	_toast.modulate.a = 0.0
	_toast_hint.modulate.a = 0.0

	_update_shards()


func _process(delta: float) -> void:
	_update_toast(delta)

	if player == null:
		return

	_caffeine_fill.size.x = BAR_WIDTH * player.caffeine.ratio()
	_momentum_fill.size.x = BAR_WIDTH * player.momentum

	# DRS — единственная надпись, которую игрок ищет глазами на скорости.
	if player.can_use_drs():
		_drs.text = "DRS ENABLED"
		_drs.modulate = Palette.FERRARI
	elif player.can_slipstream():
		_drs.text = "СЛИПСТРИМ"
		_drs.modulate = Abilities.color(Abilities.Kind.SLIPSTREAM)
	else:
		_drs.text = ""

	if player.stalk_active:
		_drs.text = "СТАЛК"
		_drs.modulate = Abilities.color(Abilities.Kind.STALK)


func _update_toast(delta: float) -> void:
	if _toast_time <= 0.0:
		return
	_toast_time = maxf(0.0, _toast_time - delta)
	var alpha := clampf(_toast_time / TOAST_FADE, 0.0, 1.0)
	_toast.modulate.a = alpha
	_toast_hint.modulate.a = alpha * 0.8


## Заголовок крупно, пояснение мелко под ним — длинная строка поперёк
## экрана перекрывает игру и не читается на скорости.
func show_toast(text: String, color: Color = Palette.SILVER, hint: String = "") -> void:
	_toast.text = text
	_toast.modulate = color
	_toast.modulate.a = 1.0
	_toast_hint.text = hint
	_toast_hint.modulate = Palette.SILVER_DIM
	_toast_hint.modulate.a = 0.8
	_toast_time = TOAST_TIME


func _update_shards() -> void:
	_shards.text = "осколки: %d" % Game.shard_count()


func _on_ability_unlocked(kind: Abilities.Kind) -> void:
	show_toast(Abilities.title(kind), Abilities.color(kind), Abilities.hint(kind))


func _on_shard_collected(_id: String, _total: int) -> void:
	_update_shards()
	show_toast("Осколок памяти", Palette.SHARD)


func _on_game_saved() -> void:
	show_toast("Сохранено", Palette.COFFEE)
