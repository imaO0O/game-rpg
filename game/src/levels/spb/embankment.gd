## Петербург, набережная (DESIGN.md §9).
##
## Последняя область начинается с дождя — он идёт здесь во всех комнатах
## и существует не для красоты: Мокрая резина без воды была бы способностью
## без предмета приложения.
extends Room

const TRAIN := "res://src/levels/transsib/train.tscn"
const CANALS := "res://src/levels/spb/canals.tscn"


func _define() -> void:
	room_id = "spb_embankment"
	room_title = "Петербург"

	background = Palette.SPB_BACKGROUND
	block_color = Palette.SPB_BLOCK
	edge_color = Palette.SPB_EDGE
	rain_amount = 90

	bounds(0, 0, 54, 24)

	block(0, 18, 54, 6)
	block(0, 0, 54, 2)
	block(0, 2, 1, 16)
	block(53, 2, 1, 16)

	# Канал под парапетом — виден, но недоступен.
	decor(0, 21, 54, 3, Palette.SPB_WATER)

	# Парапет набережной.
	for i in 8:
		block(6 + i * 6, 17, 1, 1)

	# Фасады на той стороне.
	decor(4, 8, 14, 10, Palette.SPB_BLOCK)
	decor(24, 6, 12, 12, Palette.SPB_BLOCK)
	decor(40, 9, 11, 9, Palette.SPB_BLOCK)

	# Лестница к осколку на карнизе.
	block(30, 14, 4, 1)
	block(37, 11, 4, 1)

	spawn("start", 5, 18)
	spawn("west", 5, 18)
	spawn("east", 48, 18)

	coffee(11, 18, "spb_embankment", "Петербург", "какао под дождём")

	shard(39, 11, "spb_01", "Набережная")

	dialogue(20, 18, "spb_embankment_pinky", "Пинки", true)

	door(2, 18, TRAIN, "spb")
	door(51, 18, CANALS, "west")
