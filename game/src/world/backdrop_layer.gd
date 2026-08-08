## Один слой фона. Рисует силуэт по семени — без текстур и без файлов.
class_name BackdropLayer
extends Node2D

var kind: Backdrop.Kind = Backdrop.Kind.CITY
var color := Color.WHITE
## Уровень земли в пикселях.
var horizon := 320.0
## Ширина полосы, которая потом зациклится.
var span := 1600.0
var height_scale := 1.0
var detail := 1.0
var rng_seed := 0

var _shapes: Array[PackedVector2Array] = []
var _lights: Array[Vector2] = []


func _ready() -> void:
	_generate()


func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	match kind:
		Backdrop.Kind.CITY: _generate_city(rng)
		Backdrop.Kind.CANAL: _generate_canal(rng)
		Backdrop.Kind.SEA: _generate_sea(rng)
		Backdrop.Kind.INDOOR: _generate_indoor(rng)


## Кварталы разной высоты с редкими окнами.
func _generate_city(rng: RandomNumberGenerator) -> void:
	var x := -span * 0.1
	while x < span * 1.1:
		var w := rng.randf_range(70.0, 190.0)
		var h := rng.randf_range(90.0, 260.0) * height_scale
		var top := horizon - h

		var shape := PackedVector2Array([
			Vector2(x, horizon),
			Vector2(x, top),
			Vector2(x + w, top),
			Vector2(x + w, horizon),
		])

		# Каждое третье здание со скатом — иначе линия крыш слишком ровная.
		if rng.randf() < 0.3:
			shape = PackedVector2Array([
				Vector2(x, horizon),
				Vector2(x, top + h * 0.18),
				Vector2(x + w * 0.5, top),
				Vector2(x + w, top + h * 0.18),
				Vector2(x + w, horizon),
			])

		_shapes.append(shape)

		# Окна только на ближних слоях: вдали они превращаются в шум.
		if detail > 0.6:
			var rows := int(h / 34.0)
			var cols := int(w / 30.0)
			for r in rows:
				for c in cols:
					if rng.randf() > 0.22:
						continue
					_lights.append(Vector2(
						x + 12.0 + c * 30.0,
						top + 16.0 + r * 34.0
					))

		x += w + rng.randf_range(6.0, 34.0)


## Плотная линия фасадов без разрывов — как на набережной.
func _generate_canal(rng: RandomNumberGenerator) -> void:
	var x := -span * 0.1
	while x < span * 1.1:
		var w := rng.randf_range(90.0, 150.0)
		var h := rng.randf_range(120.0, 200.0) * height_scale
		var top := horizon - h

		_shapes.append(PackedVector2Array([
			Vector2(x, horizon),
			Vector2(x, top),
			Vector2(x + w * 0.5, top - h * 0.12),
			Vector2(x + w, top),
			Vector2(x + w, horizon),
		]))

		if detail > 0.6:
			var cols := int(w / 26.0)
			for c in cols:
				if rng.randf() > 0.3:
					continue
				_lights.append(Vector2(x + 10.0 + c * 26.0, top + 30.0))

		x += w


## Низкая линия берега и редкие пальмы.
func _generate_sea(rng: RandomNumberGenerator) -> void:
	var points := PackedVector2Array()
	points.append(Vector2(-span * 0.1, horizon))

	var x := -span * 0.1
	while x < span * 1.1:
		var h := rng.randf_range(20.0, 70.0) * height_scale
		points.append(Vector2(x, horizon - h))
		x += rng.randf_range(80.0, 200.0)

	points.append(Vector2(span * 1.1, horizon))
	_shapes.append(points)

	if detail < 0.6:
		return

	x = -span * 0.1
	while x < span * 1.1:
		if rng.randf() < 0.4:
			var trunk := rng.randf_range(50.0, 90.0) * height_scale
			_shapes.append(PackedVector2Array([
				Vector2(x - 2.0, horizon),
				Vector2(x - 4.0, horizon - trunk),
				Vector2(x + 4.0, horizon - trunk),
				Vector2(x + 2.0, horizon),
			]))
		x += rng.randf_range(140.0, 320.0)


## Дальняя стена помещения: колонны и проёмы.
func _generate_indoor(rng: RandomNumberGenerator) -> void:
	var x := -span * 0.1
	while x < span * 1.1:
		var w := rng.randf_range(40.0, 90.0)
		var h := rng.randf_range(140.0, 240.0) * height_scale
		_shapes.append(PackedVector2Array([
			Vector2(x, horizon),
			Vector2(x, horizon - h),
			Vector2(x + w, horizon - h),
			Vector2(x + w, horizon),
		]))
		x += w + rng.randf_range(30.0, 90.0)


func _draw() -> void:
	for shape in _shapes:
		draw_colored_polygon(shape, color)

	# Окна тёплые и тусклые: яркие точки на фоне перетягивают взгляд
	# с игрока, а он должен оставаться самым заметным пятном в кадре.
	var light := color.lerp(Palette.WINDOW_LIGHT, 0.5)
	for point in _lights:
		draw_rect(Rect2(point, Vector2(6.0, 9.0)), light)
