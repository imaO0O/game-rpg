## Отрисовка персонажа.
##
## Катя рисуется кодом, а не спрайтом: силуэт с процедурной анимацией
## читается на любом разрешении и не требует листа кадров. Всё движение
## выводится из скорости — цикл шага, наклон корпуса, инерция волос
## и шарфа. Поэтому анимация никогда не расходится с физикой.
##
## Цвет — Ferrari red (DESIGN.md §8): единственное красное пятно
## в зелёном мире, всегда читается на любом фоне.
class_name PlayerVisual
extends Node2D

const BODY := Palette.FERRARI
const SHADE := Color("8e0000")
const DARK := Color("4a0505")
const HAIR := Color("2a0a0a")
const HIGHLIGHT := Color("ff6b5a")

## Высота фигуры в логических единицах — совпадает с коллизией.
const HEIGHT := 20.0
const HIP_Y := -8.5
const SHOULDER_Y := -15.0
const HEAD_Y := -17.4
const HEAD_R := 3.1

## Сегменты волос: чем дальше от головы, тем сильнее отстают.
const HAIR_SEGMENTS := 5
const HAIR_STEP := 1.5

var player: Player

var _run_cycle := 0.0
var _lean := 0.0
var _breathe := 0.0
## Мировые позиции сегментов волос — тянутся за головой с задержкой.
var _hair_points: PackedVector2Array = []
var _scarf_points: PackedVector2Array = []


func _ready() -> void:
	player = get_parent() as Player
	_hair_points.resize(HAIR_SEGMENTS)
	_scarf_points.resize(HAIR_SEGMENTS)
	_reset_trails()


func _reset_trails() -> void:
	var head := global_position + Vector2(0.0, HEAD_Y)
	for i in HAIR_SEGMENTS:
		_hair_points[i] = head
		_scarf_points[i] = global_position + Vector2(0.0, SHOULDER_Y)


func _process(delta: float) -> void:
	if player == null:
		return

	var speed := absf(player.velocity.x)
	var ratio := clampf(speed / player.config.top_speed, 0.0, 1.0)

	# Цикл шага крутится от пройденного пути, а не от времени: тогда
	# ноги не «скользят» при изменении скорости.
	if player.is_on_floor():
		_run_cycle += speed * delta * 0.09
	else:
		_run_cycle = lerpf(_run_cycle, 0.0, 1.0 - exp(-6.0 * delta))

	_breathe += delta * 2.2

	# Наклон вперёд тем сильнее, чем быстрее бежит.
	var want_lean := signf(player.velocity.x) * ratio * 0.34
	_lean = lerpf(_lean, want_lean, 1.0 - exp(-9.0 * delta))

	_update_trail(_hair_points, global_position + Vector2(0.0, HEAD_Y), delta, 34.0, HAIR_STEP)
	_update_trail(_scarf_points, global_position + Vector2(0.0, SHOULDER_Y), delta, 22.0, 1.8)

	queue_redraw()


## Цепочка сегментов, догоняющих точку крепления. Даёт инерцию
## без физических узлов: волосы отстают на разгоне и опадают на месте.
func _update_trail(points: PackedVector2Array, anchor: Vector2, delta: float, stiffness: float, step: float) -> void:
	points[0] = anchor
	for i in range(1, points.size()):
		var target: Vector2 = points[i - 1]
		var current: Vector2 = points[i]
		var pull := 1.0 - exp(-stiffness * delta)
		current = current.lerp(target, pull)

		# Держим длину сегмента и подвешиваем к низу — иначе волосы
		# схлопываются в точку.
		var offset := current - target
		if offset.length() < 0.001:
			offset = Vector2(0.0, step)
		current = target + offset.normalized() * step + Vector2(0.0, step * 0.35)
		points[i] = current


func _draw() -> void:
	if player == null:
		return

	var facing := float(player.facing)
	var airborne := not player.is_on_floor()
	var vy := player.velocity.y

	# Общий наклон корпуса.
	draw_set_transform(Vector2.ZERO, _lean, Vector2.ONE)

	_draw_trail(_scarf_points, SHADE, 2.4)
	_draw_legs(facing, airborne, vy)
	_draw_torso(facing)
	_draw_arms(facing, airborne, vy)
	_draw_head(facing)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_trail(_hair_points, HAIR, 3.2)


func _draw_legs(facing: float, airborne: bool, vy: float) -> void:
	var swing := sin(_run_cycle) * 3.4
	var lift := cos(_run_cycle) * 1.2

	if airborne:
		# В прыжке ноги подобраны, при падении — вытянуты вперёд.
		var tuck := clampf(-vy / 300.0, -1.0, 1.0)
		swing = 2.2 * tuck
		lift = 1.4 * maxf(tuck, 0.0)

	var hip := Vector2(0.0, HIP_Y)
	_draw_limb(hip, hip + Vector2(facing * swing, HEIGHT * 0.44 - lift), 3.0, DARK)
	_draw_limb(hip, hip + Vector2(-facing * swing * 0.8, HEIGHT * 0.44), 3.0, SHADE)


func _draw_arms(facing: float, airborne: bool, vy: float) -> void:
	var swing := -sin(_run_cycle) * 2.8
	if airborne:
		swing = -1.8 if vy < 0.0 else 1.2

	var shoulder := Vector2(0.0, SHOULDER_Y + 0.8)
	_draw_limb(shoulder, shoulder + Vector2(facing * swing, 5.6), 2.3, DARK)
	_draw_limb(shoulder, shoulder + Vector2(-facing * swing * 0.7, 5.6), 2.3, SHADE)


func _draw_limb(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	draw_line(from, to, color, width, true)
	draw_circle(to, width * 0.5, color)


func _draw_torso(facing: float) -> void:
	var breathe := sin(_breathe) * 0.12
	var top := SHOULDER_Y + breathe
	var half_top := 3.4
	var half_hip := 2.7

	var pts := PackedVector2Array([
		Vector2(-half_top + facing * 0.3, top),
		Vector2(half_top + facing * 0.3, top),
		Vector2(half_hip, HIP_Y),
		Vector2(-half_hip, HIP_Y),
	])
	draw_colored_polygon(pts, BODY)

	# Блик по ведущей стороне — объём без источника света.
	var lit := PackedVector2Array([
		Vector2(half_top * 0.2 + facing * 0.3, top),
		Vector2(half_top + facing * 0.3, top),
		Vector2(half_hip, HIP_Y),
		Vector2(half_hip * 0.3, HIP_Y),
	])
	draw_colored_polygon(lit, HIGHLIGHT if facing > 0.0 else SHADE)


func _draw_head(facing: float) -> void:
	var breathe := sin(_breathe) * 0.12
	var centre := Vector2(facing * 0.5, HEAD_Y + breathe)

	draw_circle(centre, HEAD_R, BODY)
	draw_circle(centre + Vector2(facing * 0.7, -0.5), HEAD_R * 0.55, HIGHLIGHT)

	# Затылок и челка — та же масса, что и хвост волос.
	draw_circle(centre + Vector2(-facing * 1.1, -0.4), HEAD_R * 0.85, HAIR)


func _draw_trail(points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size() < 2:
		return

	# Точки хранятся в мировых координатах — переводим в локальные.
	var local := PackedVector2Array()
	for p in points:
		local.append(to_local(p))

	for i in range(local.size() - 1):
		var t := float(i) / float(local.size() - 1)
		draw_line(local[i], local[i + 1], color, width * (1.0 - t * 0.6), true)


## Вызывается при телепорте: иначе волосы тянутся через всю комнату.
func snap() -> void:
	_reset_trails()
