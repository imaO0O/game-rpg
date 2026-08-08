## Москва, площадь трёх вокзалов (DESIGN.md §9).
##
## Место выбрано не за красоту: на Комсомольской площади действительно
## сходятся три вокзала, и вся железнодорожная сеть страны идёт через нёе.
## Поэтому именно здесь дальше открывается Пит-стоп.
extends Room

const TRAIN := "res://src/levels/transsib/train.tscn"
const PLATFORMS := "res://src/levels/moscow/platforms.tscn"


func _define() -> void:
	room_id = "moscow_square"
	room_title = "Москва"

	background = Palette.MOSCOW_BACKGROUND
	block_color = Palette.MOSCOW_BLOCK
	edge_color = Palette.MOSCOW_EDGE

	bounds(0, 0, 56, 24)

	block(0, 18, 56, 6)
	block(0, 0, 56, 2)
	block(0, 2, 1, 16)
	block(55, 2, 1, 16)

	# Три фасада на заднем плане — вся суть площади в одной строчке каждый.
	decor(4, 6, 12, 12, Palette.MOSCOW_BLOCK)
	decor(21, 4, 13, 14, Palette.MOSCOW_BLOCK)
	decor(39, 7, 12, 11, Palette.MOSCOW_BLOCK)

	# Окна: единственное, что отличает вокзал от стены.
	for i in 4:
		decor(6 + i * 3, 9, 1, 2, Palette.LAMP)
		decor(23 + i * 3, 7, 1, 2, Palette.LAMP)
		decor(41 + i * 3, 10, 1, 2, Palette.LAMP)

	# Киоски.
	block(12, 16, 3, 2)
	block(30, 15, 4, 1)
	block(36, 12, 4, 1)

	spawn("start", 6, 18)
	spawn("west", 6, 18)
	spawn("east", 50, 18)

	coffee(19, 18, "moscow_square", "Москва", "американо на бегу")

	shard(38, 12, "moscow_01", "Площадь трёх вокзалов")

	dialogue(26, 18, "moscow_square_pinky", "Пинки")

	door(2, 18, TRAIN, "moscow")
	door(53, 18, PLATFORMS, "west")
