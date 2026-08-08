## Многослойный фон с параллаксом.
##
## Пустой цвет за геометрией — главное, что выдаёт прототип. Здесь слои
## силуэтов уезжают с разной скоростью и осветляются вдаль: воздушная
## перспектива делает плоскую сцену объёмной без единой текстуры.
##
## Силуэты генерируются по семени, поэтому одна и та же комната всегда
## выглядит одинаково, а разные — по-разному.
class_name Backdrop
extends ParallaxBackground

enum Kind {
	CITY,     ## Кварталы: Рязань, Москва
	SEA,      ## Море и низкий берег: Сочи
	CANAL,    ## Плотная линия фасадов: Петербург
	INDOOR,   ## Стены помещения: дом, депо, вагон
}

## Слои от дальнего к ближнему: скорость прокрутки и осветление.
##
## Все слои заметно темнее игровой геометрии: фон обязан уходить назад,
## а не спорить с тем, по чему игрок бежит. Высоты подобраны так, чтобы
## силуэты не лезли в рабочую часть кадра.
const LAYERS := [
	{"motion": 0.06, "fade": 0.80, "height": 0.40, "detail": 0.3},
	{"motion": 0.16, "fade": 0.66, "height": 0.52, "detail": 0.6},
	{"motion": 0.32, "fade": 0.52, "height": 0.64, "detail": 1.0},
]


## Фон из готовых слоёв-картинок.
##
## Процедурные силуэты дают форму, но не дают фактуры — небо, облака
## и дальние крыши нарисованы художником лучше, чем их посчитает шейдер.
## Оттенок каждого слоя приводится к палитре области через modulate,
## поэтому один набор картинок обслуживает разные города.
##
## `specs` — массив словарей: texture, motion, scale, y, tint.
func build_textured(specs: Array, width: float) -> void:
	for spec: Dictionary in specs:
		var texture: Texture2D = spec.texture
		if texture == null:
			continue

		var scale: float = spec.get("scale", 2.0)
		var layer := ParallaxLayer.new()
		layer.motion_scale = Vector2(spec.motion, spec.get("motion_y", spec.motion * 0.4))
		# Зацикливаем по ширине самой картинки, иначе на длинной комнате
		# фон кончится посреди неё.
		layer.motion_mirroring = Vector2(texture.get_width() * scale, 0.0)
		add_child(layer)

		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.scale = Vector2(scale, scale)
		sprite.position = Vector2(0.0, spec.get("y", 0.0))
		sprite.modulate = spec.get("tint", Color.WHITE)
		sprite.z_index = -100 + int(spec.motion * 10.0)
		layer.add_child(sprite)


## Собирает фон под область. `horizon` — уровень земли в пикселях.
func build(kind: Kind, base: Color, sky: Color, horizon: float, width: float, seed_value: int) -> void:
	for i in LAYERS.size():
		var spec: Dictionary = LAYERS[i]

		var layer := ParallaxLayer.new()
		layer.motion_scale = Vector2(spec.motion, spec.motion * 0.35)
		layer.motion_mirroring = Vector2(width, 0.0)
		add_child(layer)

		var painter := BackdropLayer.new()
		painter.kind = kind
		# Дальние слои выцветают к цвету неба — это и есть воздушная перспектива.
		painter.color = base.lerp(sky, spec.fade)
		painter.horizon = horizon
		painter.span = width
		painter.height_scale = spec.height
		painter.detail = spec.detail
		painter.rng_seed = seed_value + i * 977
		painter.z_index = -100 + i
		layer.add_child(painter)
