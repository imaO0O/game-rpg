## Петербург, крыши. Обход мокрой секции (DESIGN.md §9).
##
## Пока сцепления нет, наверх ведёт единственный путь — и он вертикальный,
## то есть ровно там, где разгон не нужен вовсе. Область сама показывает,
## чего игроку не хватает, не говоря об этом словами.
extends Room

const CANALS := "res://src/levels/spb/canals.tscn"
const COURTYARD := "res://src/levels/spb/courtyard.tscn"


func _define() -> void:
	room_id = "spb_roofs"
	room_title = "Крыши"

	background = Palette.SPB_BACKGROUND
	block_color = Palette.SPB_BLOCK
	edge_color = Palette.SPB_EDGE
	rain_amount = 130

	bounds(0, 0, 48, 36)

	block(0, 32, 48, 4)
	block(0, 0, 48, 2)
	block(0, 2, 1, 30)
	block(47, 2, 1, 30)

	# Скаты: шаг три тайла по вертикали и с перехлёстом по горизонтали,
	# иначе на мокрой крыше прыжок не достаёт.
	block(4, 29, 8, 1)
	block(11, 26, 8, 1)
	block(4, 23, 8, 1)
	block(11, 20, 8, 1)
	block(20, 17, 8, 1)
	block(30, 14, 8, 1)
	block(20, 11, 8, 1)
	block(10, 8, 10, 1)
	block(4, 5, 8, 1)

	# Трубы.
	block(8, 27, 1, 2)
	block(33, 12, 1, 2)

	spawn("start", 5, 32)
	spawn("canals", 5, 32)
	spawn("courtyard", 8, 5)

	shard(24, 11, "spb_04", "Крыши")

	dialogue(6, 32, "spb_roofs_pinky", "Пинки")

	door(2, 32, CANALS, "roofs")
	door(12, 5, COURTYARD, "start")
