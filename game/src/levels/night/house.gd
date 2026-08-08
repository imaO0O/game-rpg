## Дом Зейда (DESIGN.md §9).
##
## Стилизация под «Преследуя Аделин» с вывернутыми ролями: в хорроре
## игрок — жертва, здесь Катя — та, кто идёт по следу. Пинки по дороге
## сообщает, что так вообще-то не должно работать.
##
## Отсюда и планировка: тесно, темно, три этажа с узкими проёмами —
## всё то, что в хорроре пугает, а здесь работает на игрока.
extends Room

const NIGHT_YARD := "res://src/levels/night/yard.tscn"
const ATTIC := "res://src/levels/night/attic.tscn"


func _define() -> void:
	room_id = "night_house"
	room_title = "Дом"

	background = Palette.NIGHT_BACKGROUND
	block_color = Palette.NIGHT_BLOCK
	edge_color = Palette.NIGHT_EDGE

	bounds(0, 0, 40, 30)

	block(0, 26, 40, 4)
	block(0, 0, 40, 2)
	block(0, 2, 1, 24)
	block(39, 2, 1, 24)

	# Перекрытия с проёмами по разные стороны: подниматься приходится
	# через весь этаж, а не по одной лестнице.
	block(0, 20, 26, 1)
	block(32, 20, 8, 1)
	block(8, 14, 32, 1)
	block(0, 8, 24, 1)

	# Мебель, по которой поднимаются между этажами.
	block(20, 23, 3, 1)
	block(27, 23, 3, 1)
	block(33, 17, 3, 1)
	block(28, 17, 3, 1)
	block(4, 11, 3, 1)
	block(10, 11, 3, 1)

	# Тусклый свет из окон — единственное освещение.
	decor(6, 22, 2, 2, Palette.WINDOW_LIGHT)
	decor(34, 10, 2, 2, Palette.WINDOW_LIGHT)

	spawn("start", 4, 26)
	spawn("west", 4, 26)
	spawn("attic", 6, 8)

	shard(24, 26, "night_02", "Первый этаж")

	# Секрет для возврата: стену видно только в Сталк-режиме,
	# а он лежит этажом выше.
	hidden_wall(18, 20, 80.0)
	shard(22, 20, "night_03", "За стеной в доме")

	dialogue(14, 26, "night_house_pinky", "Пинки", true)

	door(2, 26, NIGHT_YARD, "house")
	door(20, 8, ATTIC, "start")
