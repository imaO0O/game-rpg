## Отрисовка персонажа готовыми спрайтами.
##
## Кадры из набора Warped City 2 (Luis Zuno @ansimuz, CC0). Анимация
## выбирается из состояния физики, а не проигрывается по сценарию:
## бежит — цикл бега, оторвался от земли — прыжок, падает — падение.
## Скорость цикла бега привязана к скорости персонажа, поэтому ноги
## не скользят по земле.
##
## Масштаб подобран так, чтобы пиксель спрайта увеличивался ровно вдвое
## при зуме камеры 6: фигура 58 px при масштабе 1/3 занимает 19.3 единицы
## мира, что совпадает с высотой коллизии. Нецелое увеличение размывало бы
## пиксель-арт.
class_name PlayerSprite
extends Node2D

const FRAME_SCALE := 1.0 / 3.0
## Ноги персонажа в кадре 80x80 — на самом низу, поэтому смещаем спрайт
## вверх на половину кадра: origin игрока находится у его ног.
const FRAME_SIZE := 80.0

const ANIMATIONS := {
	"idle": {"frames": 4, "fps": 6.0, "loop": true},
	"run": {"frames": 8, "fps": 14.0, "loop": true},
	"jump": {"frames": 7, "fps": 12.0, "loop": false},
	"duck": {"frames": 4, "fps": 8.0, "loop": false},
	"hurt": {"frames": 1, "fps": 1.0, "loop": false},
}

var player: Player
var _sprite: AnimatedSprite2D
var _current := ""


func _ready() -> void:
	player = get_parent() as Player

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _build_frames()
	_sprite.scale = Vector2(FRAME_SCALE, FRAME_SCALE)
	_sprite.position = Vector2(0.0, -FRAME_SIZE * FRAME_SCALE * 0.5)
	# Пиксель-арт нельзя сглаживать — иначе он превращается в кашу.
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)

	_play("idle")


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	for name: String in ANIMATIONS:
		var spec: Dictionary = ANIMATIONS[name]
		frames.add_animation(name)
		frames.set_animation_speed(name, spec.fps)
		frames.set_animation_loop(name, spec.loop)

		for i in spec.frames:
			var path := "res://assets/warped/player/%s_%d.png" % [name, i]
			if not ResourceLoader.exists(path):
				push_warning("Нет кадра %s" % path)
				continue
			frames.add_frame(name, load(path))

	return frames


func _process(_delta: float) -> void:
	if player == null:
		return

	_sprite.flip_h = player.facing < 0

	var speed := absf(player.velocity.x)

	if not player.is_on_floor():
		_play("jump")
		# Кадр прыжка выбираем по вертикальной скорости: взлёт — первые,
		# зависание — средние, падение — последние.
		var t := clampf(inverse_lerp(player.config.jump_velocity, player.config.max_fall_speed, player.velocity.y), 0.0, 1.0)
		_sprite.frame = int(t * (ANIMATIONS.jump.frames - 1))
		return

	if speed > 6.0:
		_play("run")
		# Ноги не должны скользить: цикл крутится тем быстрее, чем выше скорость.
		_sprite.speed_scale = clampf(speed / player.config.base_speed, 0.45, 2.6)
		return

	_play("idle")
	_sprite.speed_scale = 1.0


func _play(name: String) -> void:
	if _current == name:
		return
	_current = name
	_sprite.play(name)


## Совместимость с прежним визуалом: телепорт не требует сброса.
func snap() -> void:
	pass
