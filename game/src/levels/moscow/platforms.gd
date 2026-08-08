## Москва, платформы. Первая комната, где Слипстрим обязателен (DESIGN.md §6).
##
## Сочи давал рывок, но обойтись без него там было можно. Здесь между
## составами разрыв, который прыжком не берётся: область учит пользоваться
## тем, что игрок уже получил, до того как выдать следующее.
extends Room

const SQUARE := "res://src/levels/moscow/square.tscn"
const UNDERGROUND := "res://src/levels/moscow/underground.tscn"

## Замеры в gap_smoke: прыжок берёт 10.3 тайла, прыжок с рывком — 13.5.
const GAP_TILES := 12


func _define() -> void:
	room_id = "moscow_platforms"
	room_title = "Платформы"

	background = Palette.MOSCOW_BACKGROUND
	block_color = Palette.MOSCOW_BLOCK
	edge_color = Palette.MOSCOW_EDGE

	bounds(0, 0, 72, 26)

	# Пути внизу — сюда падать нельзя.
	decor(0, 22, 72, 4, Palette.RAIL)

	block(0, 0, 72, 2)
	block(0, 2, 1, 24)
	block(71, 2, 1, 24)

	# Платформа отправления.
	block(0, 20, 26, 6)

	# Разрыв между составами: без рывка не берётся.
	block(26 + GAP_TILES, 20, 34 - GAP_TILES, 6)
	block(64, 20, 8, 6)

	# Составы стоят рядом — по их крышам идёт верхний путь.
	block(4, 16, 14, 1)
	block(22, 13, 12, 1)
	block(40, 16, 14, 1)

	# Фонари над платформой.
	for i in 6:
		decor(6 + i * 10, 4, 1, 3, Palette.LAMP)

	spawn("start", 5, 20)
	spawn("west", 5, 20)
	spawn("east", 67, 20)

	# Награда за верхний путь — туда без рывка тоже не подняться.
	shard(28, 13, "moscow_02", "Крыши составов")

	dialogue(10, 20, "moscow_platforms_pitwall", "Пит-волл")

	door(2, 20, SQUARE, "east")
	door(69, 20, UNDERGROUND, "west")
