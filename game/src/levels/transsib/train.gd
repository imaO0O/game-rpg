## Вагон Транссиба — хаб между областями (DESIGN.md §9).
##
## Не меню и не карта: по хабу ходят ногами. Между областями всегда есть
## вагон, потому что дорога — это и есть содержание игры.
extends Room

const RYAZAN_PARK := "res://src/levels/ryazan/park.tscn"
const SOCHI_PROMENADE := "res://src/levels/sochi/promenade.tscn"
const MOSCOW_SQUARE := "res://src/levels/moscow/square.tscn"
const NIGHT_YARD := "res://src/levels/night/yard.tscn"
const SPB_EMBANKMENT := "res://src/levels/spb/embankment.tscn"


func _define() -> void:
	room_id = "transsib_train"
	room_title = "Транссиб"

	bounds(0, 0, 60, 14)

	block(0, 10, 60, 4)
	block(0, 0, 60, 2)
	block(0, 2, 1, 8)
	block(59, 2, 1, 8)

	# Окна: единственное, что отличает вагон от коридора.
	for i in 7:
		decor(5 + i * 8, 4, 5, 3, Palette.SEA)

	# Столики между окнами.
	block(11, 9, 2, 1)
	block(35, 9, 2, 1)

	spawn("start", 5, 10)
	spawn("ryazan", 5, 10)
	spawn("moscow", 20, 10)
	spawn("night", 31, 10)
	spawn("spb", 43, 10)
	spawn("sochi", 52, 10)

	dialogue(25, 10, "transsib_pinky", "Пинки")

	# Края вагона — конечные станции, середина — пересадки по нажатию.
	door(2, 10, RYAZAN_PARK, "exit")
	door_here(16, 10, MOSCOW_SQUARE, "west", "сойти в Москве")
	door_here(27, 10, NIGHT_YARD, "west", "сойти в Рязани")
	door_here(39, 10, SPB_EMBANKMENT, "west", "сойти в Петербурге")
	door(57, 10, SOCHI_PROMENADE, "west")
