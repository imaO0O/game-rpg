## Чердак дома Зейда. Здесь открывается Сталк-режим (DESIGN.md §6).
##
## Самая тесная комната в игре — ровно там, где выдаётся способность
## видеть сквозь стены. После неё в мир возвращаются все скрытые стены,
## мимо которых игрок уже проходил.
extends Room

const HOUSE := "res://src/levels/night/house.tscn"


func _define() -> void:
	room_id = "night_attic"
	room_title = "Чердак"

	background = Palette.NIGHT_BACKGROUND
	block_color = Palette.NIGHT_BLOCK
	edge_color = Palette.NIGHT_EDGE

	# Самое тёмное место в игре — ровно там, где выдают зрение сквозь стены.
	ambient = Color(0.16, 0.18, 0.24)
	player_light = 85.0

	bounds(0, 0, 32, 16)

	block(0, 12, 32, 4)
	block(0, 0, 32, 3)
	block(0, 3, 1, 9)
	block(31, 3, 1, 9)

	# Скаты крыши: чем дальше, тем ниже — к дальнему углу приходится ползти.
	block(2, 4, 6, 1)
	block(10, 5, 6, 1)
	block(18, 6, 6, 1)
	block(26, 7, 5, 1)

	# Стропила.
	block(9, 9, 1, 3)
	block(21, 9, 1, 3)

	# Слуховое окно — единственный источник света на чердаке.
	window(14, 8, 3, 3, Palette.WINDOW_LIGHT, 1.0)

	spawn("start", 4, 12)

	shard(12, 12, "night_04", "Чердак")

	# Собственно Сталк-режим — в дальнем углу под самым скатом.
	ability(28, 12, Abilities.Kind.STALK)

	dialogue(24, 12, "night_attic_pinky", "Пинки")

	door(2, 12, HOUSE, "attic")
