## Ночная Рязань, двор (DESIGN.md §9).
##
## Геометрия буквально та же, что в прологе — не похожая, а та же самая:
## приём работает, только если игрок узнаёт место ногами, до того как
## прочтёт название. Меняются цвет, свет и то, кто здесь ходит.
extends "res://src/levels/ryazan/yard.gd"

const TRAIN := "res://src/levels/transsib/train.tscn"
const HOUSE := "res://src/levels/night/house.tscn"

## Слои фона — рисованные, из набора GothicVania (CC0, Luis Zuno).
## Оттенок приводим к ночной палитре: исходник закатно-розовый.
const SKY := preload("res://assets/gothicvania/layers/background.png")
const ROOFS := preload("res://assets/gothicvania/layers/middleground.png")


func _define() -> void:
	room_id = "night_yard"
	room_title = "Двор. Ночь"

	background = Palette.NIGHT_BACKGROUND
	block_color = Palette.NIGHT_BLOCK
	edge_color = Palette.NIGHT_EDGE

	# Ночь: почти всё гасим, видно только то, что освещено.
	ambient = Color(0.26, 0.30, 0.38)
	player_light = 120.0
	haze = 0.18

	# Небо и дальние крыши. Тинт уводит закатный оригинал в холодную ночь.
	backdrop_layers = [
		{
			"texture": SKY,
			"motion": 0.05,
			"scale": 1.6,
			"y": -80.0,
			"tint": Color(0.34, 0.40, 0.58),
		},
		{
			"texture": ROOFS,
			"motion": 0.22,
			"scale": 1.6,
			"y": 24.0,
			"tint": Color(0.30, 0.38, 0.46),
		},
	]

	# Та же планировка, что днём.
	layout()

	# Единственное горящее окно во всём дворе. Оно же — цель.
	window(46, 7, 2, 2, Palette.WINDOW_LIGHT, 1.1)

	# Фонарь у подъезда и свет из кофейни — больше во дворе ничего не горит.
	lamp(20, 14, Color(0.85, 0.88, 0.95), 0.8, 130.0)
	lamp(9, 17, Palette.COFFEE, 0.7, 90.0)

	spawn("start", 5, 18)
	spawn("west", 5, 18)
	spawn("house", 49, 18)

	# Кофейня на том же месте, что и днём.
	coffee(9, 18, "night_yard", "Рязань ночью", "то же, что и днём")

	shard(12, 12, "night_01", "Двор ночью")

	dialogue(22, 18, "night_yard_pinky", "Пинки", true)

	door(2, 18, TRAIN, "night")
	door(54, 18, HOUSE, "west")
