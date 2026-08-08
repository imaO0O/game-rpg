## Сочи, боксы. Здесь лежит Слипстрим (DESIGN.md §6).
##
## Способность, названная в честь того, что делают в гонке за чужой
## машиной, логично лежит там, где машины и стоят.
extends Room

const TURN3 := "res://src/levels/sochi/turn3.tscn"


func _define() -> void:
	room_id = "sochi_paddock"
	room_title = "Боксы"

	background = Palette.SOCHI_BACKGROUND
	block_color = Palette.SOCHI_BLOCK
	edge_color = Palette.SOCHI_EDGE

	bounds(0, 0, 40, 18)

	block(0, 14, 40, 4)
	block(0, 0, 40, 2)
	block(0, 2, 1, 12)
	block(39, 2, 1, 12)

	# Навесы над боксами.
	block(9, 8, 7, 1)
	block(19, 8, 7, 1)
	block(29, 8, 7, 1)

	# Ящики, по которым туда забираются.
	block(6, 12, 2, 2)
	block(17, 11, 2, 1)

	spawn("start", 6, 14)
	spawn("west", 6, 14)

	shard(22, 8, "sochi_04", "Боксы")

	# Собственно Слипстрим — в дальнем боксе.
	ability(34, 14, Abilities.Kind.SLIPSTREAM)

	dialogue(26, 14, "sochi_paddock_pitwall", "Пит-волл")

	door(2, 14, TURN3, "paddock")
