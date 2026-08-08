## Москва, подземные переходы (DESIGN.md §9).
##
## Здесь спрятан секрет, который сейчас взять нельзя: за скрытой стеной,
## а Сталк-режим игрок получит только в ночной Рязани. Это намеренно —
## метроидвания обязана оставлять видимые места, до которых пока не дотянуться.
extends Room

const PLATFORMS := "res://src/levels/moscow/platforms.tscn"
const DEPOT := "res://src/levels/moscow/depot.tscn"


func _define() -> void:
	room_id = "moscow_underground"
	room_title = "Переходы"

	background = Palette.MOSCOW_BACKGROUND
	block_color = Palette.MOSCOW_BLOCK
	edge_color = Palette.MOSCOW_EDGE

	bounds(0, 0, 52, 22)

	block(0, 18, 52, 4)
	block(0, 0, 52, 2)
	block(0, 2, 1, 16)
	block(51, 2, 1, 16)

	# Своды переходов — низкие, бежать под ними можно, прыгать нельзя.
	block(6, 15, 10, 1)
	block(34, 15, 10, 1)

	# Массив над змеиной дверью: обойти поверху нельзя.
	block(22, 2, 4, 11)

	# Лестница на верхний ярус.
	block(28, 15, 3, 1)
	block(32, 12, 16, 1)

	spawn("start", 5, 18)
	spawn("west", 5, 18)
	spawn("east", 46, 18)

	# Змеиная дверь на основном проходе. Змееуст у игрока уже есть —
	# это не гейт, а напоминание, что способность никуда не делась.
	snake_door(24, 18, "moscow_underground", 80.0)

	shard(18, 18, "moscow_03", "Переход")

	# Секрет за скрытой стеной: виден, но недоступен до Сталк-режима.
	hidden_wall(36, 12, 80.0)
	shard(42, 12, "moscow_04", "За стеной перехода")

	dialogue(12, 18, "moscow_underground_pinky", "Пинки")

	door(2, 18, PLATFORMS, "east")
	door(49, 18, DEPOT, "west")
