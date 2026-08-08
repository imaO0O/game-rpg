## Освещение (DESIGN.md §13).
##
## Свет — самое дешёвое, что отличает игру от прототипа: та же геометрия
## под разным светом читается как разные места. Текстуры света генерируются
## градиентами прямо в коде, чтобы не тянуть внешние файлы и не зависеть
## от арта, которого ещё нет.
class_name Lighting
extends RefCounted

static var _round_texture: GradientTexture2D
static var _beam_texture: GradientTexture2D


## Круглое пятно света: окна, фонари, аура игрока.
static func round_light() -> GradientTexture2D:
	if _round_texture != null:
		return _round_texture

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.45),
		Color(1.0, 1.0, 1.0, 0.0),
	])

	_round_texture = GradientTexture2D.new()
	_round_texture.gradient = gradient
	_round_texture.fill = GradientTexture2D.FILL_RADIAL
	_round_texture.fill_from = Vector2(0.5, 0.5)
	_round_texture.fill_to = Vector2(1.0, 0.5)
	_round_texture.width = 256
	_round_texture.height = 256
	return _round_texture


## Мягкая вертикальная полоса: свет из окна, падающий вниз.
static func beam_light() -> GradientTexture2D:
	if _beam_texture != null:
		return _beam_texture

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.8),
		Color(1.0, 1.0, 1.0, 0.0),
	])

	_beam_texture = GradientTexture2D.new()
	_beam_texture.gradient = gradient
	_beam_texture.fill = GradientTexture2D.FILL_LINEAR
	_beam_texture.fill_from = Vector2(0.5, 0.0)
	_beam_texture.fill_to = Vector2(0.5, 1.0)
	_beam_texture.width = 128
	_beam_texture.height = 256
	return _beam_texture


## Источник света. `radius` — примерный радиус в пикселях.
static func make_point(color: Color, energy: float, radius: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = round_light()
	light.color = color
	light.energy = energy
	# Текстура 256 px в поперечнике, значит масштаб — доля от её половины.
	light.texture_scale = radius / 128.0
	light.blend_mode = Light2D.BLEND_MODE_ADD
	return light


## Луч из окна: то же, но вытянутый вниз.
static func make_beam(color: Color, energy: float, width: float, height: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = beam_light()
	light.color = color
	light.energy = energy
	light.texture_scale = 1.0
	light.scale = Vector2(width / 128.0, height / 256.0)
	light.blend_mode = Light2D.BLEND_MODE_ADD
	# Текстура тянется вниз от своего верха.
	light.offset = Vector2(0.0, 128.0)
	return light
