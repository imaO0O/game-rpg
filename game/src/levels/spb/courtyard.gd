## Петербург, двор-колодец. Здесь лежит Мокрая резина (DESIGN.md §6).
##
## Последняя способность — и последняя комната, куда игрок попадает
## пешком. На дне колодца лужа: сцепление находится стоя в воде,
## которая до этой секунды мешала.
extends Room

const ROOFS := "res://src/levels/spb/roofs.tscn"


func _define() -> void:
	room_id = "spb_courtyard"
	room_title = "Двор-колодец"

	background = Palette.SPB_BACKGROUND
	block_color = Palette.SPB_BLOCK
	edge_color = Palette.SPB_EDGE
	rain_amount = 70

	bounds(0, 0, 28, 30)

	block(0, 26, 28, 4)
	block(0, 0, 28, 2)
	block(0, 2, 1, 24)
	block(27, 2, 1, 24)

	# Карнизы по стенам колодца — спуск и подъём.
	block(3, 20, 4, 1)
	block(21, 17, 4, 1)
	block(3, 14, 4, 1)
	block(21, 11, 4, 1)
	block(10, 8, 6, 1)

	# Лужа на дне.
	decor(8, 25, 14, 1, Palette.SPB_WATER)
	water(8, 26, 14)

	spawn("start", 5, 26)
	spawn("roofs", 5, 26)

	shard(23, 11, "spb_05", "Двор-колодец")

	ability(18, 26, Abilities.Kind.WET_TYRES)

	dialogue(13, 26, "spb_courtyard_pinky", "Пинки")

	door(2, 26, ROOFS, "courtyard")
