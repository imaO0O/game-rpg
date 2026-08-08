## Сочи, стартовая прямая. Здесь momentum наконец имеет смысл (DESIGN.md §5).
##
## Самая длинная прямая в игре: сорок тайлов без единого препятствия,
## чтобы разгон дошёл до предела и открылся DRS. Всё, что мешало бы
## держать линию, вынесено за её пределы намеренно.
##
## В конце — пропасть, которую не перепрыгнуть даже на полной скорости.
## Это гейт Слипстрима и первый раз, когда игра говорит «пока нет».
extends Room

const PROMENADE := "res://src/levels/sochi/promenade.tscn"
const TURN3 := "res://src/levels/sochi/turn3.tscn"

## Ширина пропасти в тайлах. Замерено тестом gap_smoke: на полном разгоне
## прыжок берёт 10.3 тайла, прыжок с рывком — 13.5. Одиннадцать оставляет
## по четверти тайла запаса в обе стороны: без рывка честно не долететь,
## с рывком не надо прыгать идеально.
const GAP_TILES := 11
const GAP_START := 58


func _define() -> void:
	room_id = "sochi_straight"
	room_title = "Стартовая прямая"

	background = Palette.SOCHI_BACKGROUND
	block_color = Palette.SOCHI_BLOCK
	edge_color = Palette.SOCHI_EDGE

	bounds(0, 0, 84, 22)

	block(0, 16, GAP_START, 6)
	block(GAP_START + GAP_TILES, 16, 84 - GAP_START - GAP_TILES, 6)
	block(0, 0, 84, 2)
	block(0, 2, 1, 14)
	block(83, 2, 1, 14)

	# Поребрики вдоль прямой — единственное украшение, зато трасса
	# сразу читается как трасса.
	for i in 10:
		decor(12 + i * 4, 15, 2, 1, Palette.KERB)

	spawn("start", 5, 16)
	spawn("west", 5, 16)
	# Возврат из виража — рядом с его входом, но не в нём.
	spawn("turn3", 50, 16)

	dialogue(6, 16, "sochi_pitwall", "Пит-волл")

	# Награда за пропасть: то, ради чего игрок сюда вернётся.
	shard(GAP_START + GAP_TILES + 4, 16, "sochi_02", "За разрывом")
	coffee(GAP_START + GAP_TILES + 12, 16, "sochi_straight", "Сочи", "лимонад с базиликом")

	door(2, 16, PROMENADE, "east")
	# Вход в вираж — у самой пропасти и только по нажатию: автоматический
	# перехватывал бы каждого, кто разбежался прыгать.
	door_here(54, 16, TURN3, "bottom", "вираж")
