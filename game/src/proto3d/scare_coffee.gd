## Скример «Кофемашина» (CONCEPT_3D.md, скример №6).
##
## Нажимаешь кнопку — машина ревёт сиреной и выплёвывает пену на весь
## экран. Разрядка: экран вытирается изнутри, кофе готов, всё в порядке.
##
## Единственный скример, который игрок запускает сам. Поэтому он и
## смешнее остальных: испугаться от собственного нажатия обиднее всего.
extends Scare

const PUNCHLINE := "Кофе готов. Приятного."
const FOAM_TIME := 1.9

var _foam: ColorRect
var _hit_sound: AudioStreamPlayer3D
var _coffee: CoffeePoint


func _ready() -> void:
	id = "coffee"
	# Своей зоны нет: запускается сигналом от кофемашины.
	trigger_size = Vector3.ZERO
	strike_time = FOAM_TIME
	super._ready()

	_hit_sound = _sound("scare_hit", -3.0)
	add_child(_hit_sound)

	_foam = _build_foam()


## Привязка к машине. Ставится до добавления в дерево.
func attach(point: CoffeePoint) -> void:
	_coffee = point
	if _coffee != null:
		_coffee.used.connect(_on_used)


func _on_used(_id: String) -> void:
	fire()


func _strike() -> void:
	_hit_sound.play()
	blackout(0.18)

	# Пена заливает кадр рывком, а не выплывает: плавное появление
	# читалось бы как переход, а не как выброс.
	_foam.visible = true
	_foam.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_foam, "modulate:a", 0.92, 0.12)


func _resolve() -> void:
	# Вытирается изнутри: сначала мутнеет, потом сходит на нет.
	var tween := create_tween()
	tween.tween_property(_foam, "modulate:a", 0.0, 1.1)
	await tween.finished

	if is_instance_valid(_foam):
		_foam.visible = false
	print("[кофемашина] %s" % PUNCHLINE)


## Пена — слой поверх кадра. Отдельным CanvasLayer, чтобы лечь
## поверх интерфейса: заливает всё, включая подсказки.
func _build_foam() -> ColorRect:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var rect := ColorRect.new()
	rect.color = Color(0.94, 0.92, 0.88, 1.0)
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = false
	layer.add_child(rect)
	return rect
