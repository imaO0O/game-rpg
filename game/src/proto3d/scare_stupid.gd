## Скример «I am stupid» (CONCEPT_3D.md, скример №10).
##
## Оступилась — свет мигает, по радио усталый голос. Тишина.
## Потом Пинки: «...он тоже так делает.»
##
## Единственный, который срабатывает от неудачи игрока, а не от места
## или действия. Поэтому он не столько пугает, сколько сочувствует:
## знаменитое радио Леклера из Имолы узнает любой болельщик, и в этом
## вся шутка — Кате напоминают, что она в хорошей компании.
extends Scare

const RADIO_LINE := "I am stupid."
const PUNCHLINE := "Пинки: ...он тоже так делает."
## Сколько раз надо стукнуться, прежде чем радио оживёт. С первого
## раза это выглядело бы придиркой.
const BUMPS_BEFORE_FIRING := 3
## Удар засчитывается только на приличной скорости: медленное
## притирание к косяку — не повод.
const BUMP_SPEED := 2.6

var _player: CharacterBody3D
var _bumps := 0
var _cooldown := 0.0
var _radio: AudioStreamPlayer3D


func _ready() -> void:
	id = "stupid"
	trigger_size = Vector3.ZERO
	strike_time = 2.4
	super._ready()

	_radio = _sound("radio_static", -6.0)
	add_child(_radio)

	_find_player.call_deferred()


func _find_player() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody3D:
			_player = node
			return


func _physics_process(delta: float) -> void:
	if _player == null:
		return

	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown > 0.0:
		return

	if not _player.is_on_wall():
		return

	# Считаем только удары на ходу: стоять лицом в стену можно сколько
	# угодно, это не неудача, а разглядывание.
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	if speed < BUMP_SPEED:
		return

	_bumps += 1
	# Пауза, иначе один заход в стену насчитает десяток ударов подряд.
	_cooldown = 1.5

	if _bumps >= BUMPS_BEFORE_FIRING:
		fire()


func _strike() -> void:
	_radio.play()
	# Короткое мигание вместо темноты: игрок и так уже врезался,
	# добивать его полной чернотой незачем.
	_flicker()
	print("[радио] %s" % RADIO_LINE)


func _resolve() -> void:
	print("[%s]" % PUNCHLINE)


## Свет дважды моргает и возвращается.
func _flicker() -> void:
	var lights := _all_lights()
	var saved := {}
	for light: Light3D in lights:
		saved[light] = light.light_energy

	for i in 2:
		for light: Light3D in saved:
			if is_instance_valid(light):
				light.light_energy = saved[light] * 0.15
		await get_tree().create_timer(0.09).timeout

		for light: Light3D in saved:
			if is_instance_valid(light):
				light.light_energy = saved[light]
		await get_tree().create_timer(0.13).timeout
