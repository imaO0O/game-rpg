## Вагон Транссиба — хаб между областями (DESIGN.md §9).
##
## Не меню и не карта: по хабу ходят ногами. Между областями всегда есть
## вагон, потому что дорога — это и есть содержание игры.
extends Room

const RYAZAN_PARK := "res://src/levels/ryazan/park.tscn"
const SOCHI_PROMENADE := "res://src/levels/sochi/promenade.tscn"
const MOSCOW_SQUARE := "res://src/levels/moscow/square.tscn"


func _define() -> void:
	room_id = "transsib_train"
	room_title = "Транссиб"

	bounds(0, 0, 44, 14)

	block(0, 10, 44, 4)
	block(0, 0, 44, 2)
	block(0, 2, 1, 8)
	block(43, 2, 1, 8)

	# Окна: единственное, что отличает вагон от коридора.
	for i in 5:
		decor(6 + i * 8, 4, 5, 3, Palette.SEA)

	# Столики между окнами.
	block(10, 9, 2, 1)
	block(26, 9, 2, 1)

	spawn("start", 5, 10)
	spawn("ryazan", 5, 10)
	spawn("moscow", 25, 10)
	spawn("sochi", 38, 10)

	dialogue(15, 10, "transsib_pinky", "Пинки")

	# Края вагона — конечные станции, середина — пересадка по нажатию.
	door(2, 10, RYAZAN_PARK, "exit")
	door_here(21, 10, MOSCOW_SQUARE, "west", "сойти в Москве")
	door(41, 10, SOCHI_PROMENADE, "west")
