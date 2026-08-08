## Москва, депо. Здесь открывается Пит-стоп (DESIGN.md §6).
##
## После этой комнаты сеть кофеен превращается в сеть перемещений,
## и дорога назад перестаёт занимать время. Логично, что это происходит
## там, где сходятся все пути страны.
extends Room

const UNDERGROUND := "res://src/levels/moscow/underground.tscn"


func _define() -> void:
	room_id = "moscow_depot"
	room_title = "Депо"

	background = Palette.MOSCOW_BACKGROUND
	block_color = Palette.MOSCOW_BLOCK
	edge_color = Palette.MOSCOW_EDGE

	bounds(0, 0, 44, 20)

	block(0, 16, 44, 4)
	block(0, 0, 44, 2)
	block(0, 2, 1, 14)
	block(43, 2, 1, 14)

	# Рельсы в полу депо.
	decor(4, 15, 36, 1, Palette.RAIL)

	# Смотровые ямы и мостки над ними.
	block(12, 10, 8, 1)
	block(24, 8, 8, 1)
	block(34, 11, 6, 1)

	# Фонари под потолком.
	for i in 4:
		decor(8 + i * 9, 3, 1, 3, Palette.LAMP)

	spawn("start", 5, 16)
	spawn("west", 5, 16)

	coffee(9, 16, "moscow_depot", "Москва", "двойной без сахара")

	shard(27, 8, "moscow_05", "Депо")

	# Собственно Пит-стоп.
	ability(38, 16, Abilities.Kind.PIT_STOP)

	dialogue(31, 16, "moscow_depot_pitwall", "Пит-волл")

	door(2, 16, UNDERGROUND, "east")
