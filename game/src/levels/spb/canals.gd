## Петербург, каналы. Гейт Мокрой резины (DESIGN.md §6).
##
## Гейт устроен не как стена, а как следствие механики: длинный мокрый
## участок, а сразу за ним разрыв. Без сцепления по воде разгон не растёт,
## к краю игрок подходит медленно и не долетает. С Мокрой резиной вода
## перестаёт что-либо значить, и тот же прыжок получается сам собой.
##
## Пройти водой можно и без способности — нельзя только улететь с неё далеко.
extends Room

const EMBANKMENT := "res://src/levels/spb/embankment.tscn"
const ROOFS := "res://src/levels/spb/roofs.tscn"

const WATER_START := 20
const WATER_TILES := 24
## Разрыв сразу за водой. Замеры в wet_smoke: без сцепления прыжок с воды
## берёт около трёх тайлов, со сцеплением — больше десяти.
const GAP_START := 46
const GAP_TILES := 7


func _define() -> void:
	room_id = "spb_canals"
	room_title = "Каналы"

	background = Palette.SPB_BACKGROUND
	block_color = Palette.SPB_BLOCK
	edge_color = Palette.SPB_EDGE
	rain_amount = 110

	bounds(0, 0, 72, 26)

	block(0, 20, GAP_START, 6)
	block(GAP_START + GAP_TILES, 20, 72 - GAP_START - GAP_TILES, 6)
	block(0, 0, 72, 2)
	block(0, 2, 1, 18)
	block(71, 2, 1, 18)

	# Разлившийся канал: по нему бежать можно, разгоняться — нет.
	decor(WATER_START, 19, WATER_TILES, 1, Palette.SPB_WATER)
	water(WATER_START, 20, WATER_TILES)

	# Мосты над водой — исключительно вид.
	decor(26, 12, 8, 1, Palette.SPB_EDGE)
	decor(38, 10, 8, 1, Palette.SPB_EDGE)

	spawn("start", 5, 20)
	spawn("west", 5, 20)
	# Возврат с крыш — до воды, чтобы разбег начинался заново.
	spawn("roofs", 13, 20)

	shard(16, 20, "spb_02", "У воды")

	# За разрывом — награда и передышка.
	shard(56, 20, "spb_03", "За разрывом")
	coffee(64, 20, "spb_canals", "Петербург", "эспрессо после дождя")

	dialogue(8, 20, "spb_canals_pinky", "Пинки")

	door(2, 20, EMBANKMENT, "east")
	# Обход по крышам — единственный путь, пока нет сцепления.
	door_here(9, 20, ROOFS, "canals", "на крышу")
