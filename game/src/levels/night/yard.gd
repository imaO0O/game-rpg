## Ночная Рязань, двор (DESIGN.md §9).
##
## Геометрия буквально та же, что в прологе — не похожая, а та же самая:
## приём работает, только если игрок узнаёт место ногами, до того как
## прочтёт название. Меняются цвет, свет и то, кто здесь ходит.
extends "res://src/levels/ryazan/yard.gd"

const TRAIN := "res://src/levels/transsib/train.tscn"
const HOUSE := "res://src/levels/night/house.tscn"


func _define() -> void:
	room_id = "night_yard"
	room_title = "Двор. Ночь"

	background = Palette.NIGHT_BACKGROUND
	block_color = Palette.NIGHT_BLOCK
	edge_color = Palette.NIGHT_EDGE

	# Та же планировка, что днём.
	layout()

	# Единственное горящее окно во всём дворе. Оно же — цель.
	decor(46, 7, 2, 2, Palette.WINDOW_LIGHT)

	spawn("start", 5, 18)
	spawn("west", 5, 18)
	spawn("house", 49, 18)

	# Кофейня на том же месте, что и днём.
	coffee(9, 18, "night_yard", "Рязань ночью", "то же, что и днём")

	shard(12, 12, "night_01", "Двор ночью")

	dialogue(22, 18, "night_yard_pinky", "Пинки", true)

	door(2, 18, TRAIN, "night")
	door(54, 18, HOUSE, "west")
