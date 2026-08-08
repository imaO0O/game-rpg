## Проверка гейта Слипстрима на стартовой прямой.
##
## Гейт обязан выполнять оба обещания: без способности не пускать,
## со способностью пускать. Если пропасть перепрыгивается на голом
## разгоне — гейта нет. Если не берётся даже с рывком — игра сломана
## и пройти её нельзя.
##
## Проверить это на глаз невозможно: разница в полтора десятка пикселей.
##
## Запуск:
##   godot --headless --path game res://tests/gap_smoke.tscn
extends Node

const STRAIGHT := preload("res://src/levels/sochi/straight.tscn")

## Координаты краёв пропасти в пикселях (см. straight.gd).
## Держать в согласии со straight.gd.
const GAP_TILES := 11
const NEAR_EDGE := 58.0 * 16.0
const FAR_EDGE := float(58 + GAP_TILES) * 16.0
## Уровень пола прямой — по нему меряется дальность прыжка.
const FLOOR_Y := 16.0 * 16.0
## Прыгать надо у самого края, иначе замер бессмысленен.
const JUMP_AT := NEAR_EDGE - 14.0
const TIMEOUT := 6.0

var _room: Room
var _player: Player

var _phase := 0
var _timer := 0.0
var _with_slipstream := false
var _crossed_without := false
var _crossed_with := false

var _failures: PackedStringArray = []
var _checks := 0

## Диагностика: без неё «не берётся» ничего не говорит о том, насколько.
var _jump_from := 0.0
var _max_x := 0.0
var _slipstream_used := false


func _ready() -> void:
	Game.reset()
	_room = STRAIGHT.instantiate()
	add_child(_room)
	_player = _room.player
	_player.slipstream_fired.connect(func() -> void: _slipstream_used = true)


func _physics_process(delta: float) -> void:
	_timer += delta

	# Дальность считаем только пока игрок не провалился ниже уровня пола:
	# иначе в замер попадает полёт вниз внутри самой пропасти.
	if _player.global_position.y <= FLOOR_Y + 2.0:
		_max_x = maxf(_max_x, _player.global_position.x)

	match _phase:
		0: _phase_run_up()
		1: _phase_airborne()
		2: _phase_settle()
		3: _phase_switch()
		4: _finish()


## Разбег по всей прямой: к краю игрок должен подойти на полном разгоне.
func _phase_run_up() -> void:
	Input.action_press("move_right")

	if _timer > TIMEOUT:
		_check(false, "разбег дошёл до края пропасти")
		_next(3)
		return

	if _player.global_position.x < JUMP_AT:
		return

	_check(
		_player.momentum > 0.9,
		"к краю подошёл на разгоне (momentum=%.2f, vx=%.0f)" % [_player.momentum, _player.velocity.x]
	)
	_jump_from = _player.global_position.x
	_max_x = _jump_from
	Input.action_press("jump")
	_next(1)


## Кнопку прыжка держим до конца подъёма: отпустить раньше — значит
## включить переменную высоту прыжка и мерить не тот прыжок.
## Рывок игрок даёт около верхней точки, а не сразу после отрыва.
func _phase_airborne() -> void:
	if _with_slipstream and not _slipstream_used and _timer >= 0.22:
		if not _player.can_slipstream():
			print("    (рывок недоступен: на земле=%s, способность=%s)" % [
				_player.is_on_floor(),
				Game.has_ability(Abilities.Kind.SLIPSTREAM),
			])
		Input.action_press("drs")

	if _timer < 0.42:
		return

	Input.action_release("jump")
	Input.action_release("drs")
	_next(2)


func _phase_settle() -> void:
	Input.action_release("drs")

	var x := _player.global_position.x

	# Перелетел: стоит на той стороне.
	if x > FAR_EDGE and _player.is_on_floor():
		_record(true)
		return

	# Упал: комната вернула его на точку входа.
	if x < NEAR_EDGE - 200.0:
		_record(false)
		return

	if _timer > TIMEOUT:
		_record(false)


func _record(crossed: bool) -> void:
	var reach := _max_x - _jump_from
	print("    прыжок %s: дальность %.0f px (%.1f тайла), пропасть %d тайлов, рывок %s" % [
		"с рывком" if _with_slipstream else "без рывка",
		reach,
		reach / 16.0,
		GAP_TILES,
		"применён" if _slipstream_used else "нет",
	])

	if _with_slipstream:
		_crossed_with = crossed
	else:
		_crossed_without = crossed
	_next(3)


func _phase_switch() -> void:
	Input.action_release("move_right")
	Input.action_release("jump")

	if _with_slipstream:
		_evaluate()
		_next(4)
		return

	# Второй заход — уже с рывком.
	_with_slipstream = true
	Game.unlock(Abilities.Kind.SLIPSTREAM)
	_player.respawn_at(Vector2(5.0 * 16.0, 16.0 * 16.0))
	_next(0)


func _evaluate() -> void:
	_check(
		not _crossed_without,
		"без Слипстрима пропасть не берётся даже на полном разгоне"
	)
	_check(
		_crossed_with,
		"со Слипстримом пропасть берётся"
	)


func _finish() -> void:
	print("")
	if _failures.is_empty():
		print("ПРОЙДЕНО: %d проверок" % _checks)
		get_tree().quit(0)
		return

	print("ПРОВАЛЕНО: %d из %d" % [_failures.size(), _checks])
	for f in _failures:
		print("  x ", f)
	get_tree().quit(1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  + ", label)
	else:
		_failures.append(label)


func _next(phase: int) -> void:
	_phase = phase
	_timer = 0.0
