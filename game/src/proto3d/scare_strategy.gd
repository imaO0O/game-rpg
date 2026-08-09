## Скример «Стратегия» (CONCEPT_3D.md, скример №5).
##
## На стене проступает указание. Через несколько секунд оно меняется
## на противоположное. Потом ещё раз. Пугает здесь не надпись, а то,
## что решение всё время другое, — и любой болельщик Ferrari узнает
## это чувство мгновенно.
##
## Разрядка встроена в саму последовательность: к четвёртой реплике
## становится ясно, что это не угроза, а знакомая беспомощность.
extends Scare

## Текст и сколько он держится. Паузы разные намеренно: ровный ритм
## читался бы как таймер, а тут важна нервозность.
const SEQUENCE := [
	{"text": "PIT STOP NOW", "hold": 4.0},
	{"text": "NO — STAY OUT", "hold": 3.2},
	{"text": "BOX BOX BOX", "hold": 2.6},
	{"text": "SORRY. YOUR CALL.", "hold": 3.4},
]

var _label: Label3D
var _step := -1
var _timer_left := 0.0
var _fade := 0.0


func _ready() -> void:
	id = "strategy"
	trigger_size = Vector3(2.6, 2.4, 2.4)
	# Держим до конца последовательности плюс запас на угасание.
	strike_time = 14.0
	super._ready()

	_label = _build_label()
	_label.visible = false
	add_child(_label)


func _process(delta: float) -> void:
	if _step < 0:
		return

	_timer_left = maxf(0.0, _timer_left - delta)

	# Проступает и гаснет: мгновенная смена читалась бы как переключение
	# слайдов, а надпись должна именно проступать сквозь штукатурку.
	var spec: Dictionary = SEQUENCE[_step]
	var appearing: float = clampf((spec.hold - _timer_left) / 0.9, 0.0, 1.0)
	var leaving: float = clampf(_timer_left / 0.7, 0.0, 1.0)
	_fade = minf(appearing, leaving)
	_label.modulate.a = _fade

	if _timer_left <= 0.0:
		_advance()


func _strike() -> void:
	_label.visible = true
	_step = -1
	_advance()


func _resolve() -> void:
	_label.visible = false
	_step = -1


func _advance() -> void:
	_step += 1
	if _step >= SEQUENCE.size():
		_step = -1
		_label.visible = false
		return

	var spec: Dictionary = SEQUENCE[_step]
	_label.text = spec.text
	_timer_left = spec.hold

	# Последняя реплика — уже не крик, а вздох: цвет уходит в серый.
	var is_last := _step == SEQUENCE.size() - 1
	_label.modulate = Color(0.55, 0.55, 0.58) if is_last else Color(0.72, 0.06, 0.05)


func _build_label() -> Label3D:
	var label := Label3D.new()
	label.font_size = 96
	label.outline_size = 0
	label.pixel_size = 0.0022
	# Без освещения: надпись проступает сама, а не отражает лампу.
	label.shaded = false
	label.double_sided = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color(0.72, 0.06, 0.05)
	return label
