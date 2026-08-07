## Шкала кофеина — топливо для рывков (DESIGN.md §5).
##
## Сама по себе не восстанавливается: только в кофейнях, которые
## по совместительству точки сохранения (DESIGN.md §10).
class_name Caffeine
extends Node

signal changed(current: float, maximum: float)
signal depleted

@export var maximum := 100.0
## Ноль по умолчанию — восстановление только через refill().
@export var regen_per_second := 0.0

var current: float

func _ready() -> void:
	current = maximum
	changed.emit(current, maximum)

func _process(delta: float) -> void:
	if regen_per_second > 0.0 and current < maximum:
		_set_current(current + regen_per_second * delta)

func can_spend(amount: float) -> bool:
	return current >= amount

## Списывает топливо. Возвращает false, если не хватило — вызывающий
## код в этом случае не должен выполнять действие.
func try_spend(amount: float) -> bool:
	if not can_spend(amount):
		return false
	_set_current(current - amount)
	if is_zero_approx(current):
		depleted.emit()
	return true

## Полный бак. Вызывается кофейнями.
func refill() -> void:
	_set_current(maximum)

func ratio() -> float:
	return current / maximum if maximum > 0.0 else 0.0

func _set_current(value: float) -> void:
	var clamped := clampf(value, 0.0, maximum)
	if is_equal_approx(clamped, current):
		return
	current = clamped
	changed.emit(current, maximum)
