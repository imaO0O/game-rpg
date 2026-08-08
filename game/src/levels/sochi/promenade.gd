## Сочи, набережная. Вход в область (DESIGN.md §9).
##
## После тесной Рязани здесь намеренно светло, широко и пусто:
## смена области должна читаться до того, как игрок прочтёт её название.
extends Room

const TRAIN := "res://src/levels/transsib/train.tscn"
const STRAIGHT := "res://src/levels/sochi/straight.tscn"


func _define() -> void:
	room_id = "sochi_promenade"
	room_title = "Сочи"

	background = Palette.SOCHI_BACKGROUND
	block_color = Palette.SOCHI_BLOCK
	edge_color = Palette.SOCHI_EDGE
	backdrop = Backdrop.Kind.SEA
	haze = 0.16

	bounds(0, 0, 52, 24)

	block(0, 18, 52, 6)
	block(0, 0, 52, 2)
	block(0, 2, 1, 16)
	block(51, 2, 1, 16)

	# Море на горизонте и солнце над ним — вся разница между
	# набережной и очередным коридором.
	decor(1, 5, 50, 9, Palette.SEA)
	decor(40, 6, 3, 3, Palette.SUN)

	# Парапет вдоль набережной.
	block(8, 17, 2, 1)
	block(16, 17, 2, 1)
	block(24, 17, 2, 1)

	# Лестница к верхнему осколку.
	block(30, 15, 4, 1)
	block(36, 12, 4, 1)

	spawn("start", 6, 18)
	spawn("west", 6, 18)
	spawn("east", 45, 18)

	coffee(13, 18, "sochi_promenade", "Сочи", "фильтр со льдом")

	shard(38, 12, "sochi_01", "Набережная")

	dialogue(20, 18, "sochi_promenade_pinky", "Пинки")

	door(2, 18, TRAIN, "sochi")
	door(49, 18, STRAIGHT, "west")
