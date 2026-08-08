## Камера с зоной нечувствительности и упреждением (DESIGN.md §5).
##
## Три вещи, ради которых она своя, а не встроенный smoothing:
## deadzone (камера не дёргается на мелких прыжках), look-ahead (смотрит туда,
## куда бежишь) и лёгкое расширение обзора на скорости.
class_name GameCamera
extends Camera2D

@export var target: Node2D

@export_group("Слежение")
## Прямоугольник вокруг центра, внутри которого цель не двигает камеру.
@export var deadzone := Vector2(20.0, 28.0)
@export var follow_smooth := 8.0

@export_group("Упреждение")
## На сколько пикселей камера смещается вперёд на максимальной скорости.
@export var look_ahead := 44.0
@export var look_ahead_smooth := 3.0

@export_group("Обзор")
## Базовый зум. Мир строится в логических единицах по 16 на тайл, а рендер
## идёт в 1920×1080 — множитель приводит одно к другому. Геометрия векторная,
## поэтому в высоком разрешении она остаётся чёткой, а не растянутой.
## Пять — это примерно двадцать четыре тайла по ширине кадра: столько же
## показывают метроидвании, на которые мы равняемся. При трёх фигура
## занимала три процента высоты экрана и терялась.
@export var zoom_base := 5.0
## Насколько расширяется кадр на полной скорости (доля зума).
@export var zoom_at_speed := 0.08
## Скорость, считающаяся максимальной. Держать в согласии с MovementConfig.top_speed.
@export var speed_reference := 260.0

@export_group("Тряска")
@export var shake_decay := 22.0
@export var shake_max := 6.0

var _center := Vector2.ZERO
var _look := 0.0
var _shake := 0.0


func _ready() -> void:
	zoom = Vector2(zoom_base, zoom_base)
	if target != null:
		_center = target.global_position
		global_position = _center


func _process(delta: float) -> void:
	if target == null:
		return

	_update_center()
	_update_look_ahead(delta)
	_update_position(delta)
	_update_zoom(delta)
	_update_shake(delta)


## Центр «тянется» за целью только когда та вышла за пределы deadzone.
func _update_center() -> void:
	var d := target.global_position - _center
	if absf(d.x) > deadzone.x:
		_center.x += d.x - signf(d.x) * deadzone.x
	if absf(d.y) > deadzone.y:
		_center.y += d.y - signf(d.y) * deadzone.y


func _update_look_ahead(delta: float) -> void:
	var want := clampf(_target_speed() / speed_reference, -1.0, 1.0) * look_ahead
	_look = lerpf(_look, want, 1.0 - exp(-look_ahead_smooth * delta))


func _update_position(delta: float) -> void:
	var goal := _center + Vector2(_look, 0.0)
	global_position = global_position.lerp(goal, 1.0 - exp(-follow_smooth * delta))


func _update_zoom(delta: float) -> void:
	# Меньший зум = шире кадр. На скорости нужно видеть дальше.
	var ratio := clampf(absf(_target_speed()) / speed_reference, 0.0, 1.0)
	var want := zoom_base * (1.0 - zoom_at_speed * ratio)
	zoom = zoom.lerp(Vector2(want, want), 1.0 - exp(-3.0 * delta))


func _update_shake(delta: float) -> void:
	if _shake <= 0.0:
		offset = Vector2.ZERO
		return
	_shake = maxf(0.0, _shake - shake_decay * delta)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake


func _target_speed() -> float:
	if target is CharacterBody2D:
		return (target as CharacterBody2D).velocity.x
	return 0.0


## Тряска при жёстком приземлении. Сила 0..1.
func shake(strength: float) -> void:
	_shake = maxf(_shake, clampf(strength, 0.0, 1.0) * shake_max)
