## Сочи, третий поворот (DESIGN.md §9).
##
## На реальном автодроме это длинный левый вираж вокруг Медальной площади —
## самый узнаваемый кусок трассы. В платформере длину поворота честно
## передать нечем, поэтому она превращена в высоту: подъём серпантином,
## который занимает столько же времени и так же не даёт держать линию.
extends Room

const STRAIGHT := "res://src/levels/sochi/straight.tscn"
const PADDOCK := "res://src/levels/sochi/paddock.tscn"


func _define() -> void:
	room_id = "sochi_turn3"
	room_title = "Третий поворот"

	background = Palette.SOCHI_BACKGROUND
	block_color = Palette.SOCHI_BLOCK
	edge_color = Palette.SOCHI_EDGE

	bounds(0, 0, 36, 46)

	block(0, 42, 36, 4)
	block(0, 0, 36, 2)
	block(0, 2, 1, 40)
	block(35, 2, 1, 40)

	# Серпантин: шаг ровно три тайла — на четыре прыжок уже не достаёт.
	block(4, 39, 10, 1)
	block(18, 36, 10, 1)
	block(4, 33, 10, 1)
	block(18, 30, 10, 1)
	block(4, 27, 10, 1)
	block(18, 24, 10, 1)
	block(4, 21, 10, 1)
	block(18, 18, 10, 1)
	block(4, 15, 10, 1)
	block(18, 12, 10, 1)
	block(4, 9, 10, 1)
	block(20, 6, 12, 1)

	# Медальная площадь в центре виража.
	decor(14, 22, 8, 8, Palette.SEA)

	spawn("start", 7, 42)
	spawn("bottom", 7, 42)
	spawn("paddock", 28, 6)

	shard(9, 21, "sochi_03", "Медальная площадь")

	door(3, 42, STRAIGHT, "turn3")
	door(32, 6, PADDOCK, "west")
