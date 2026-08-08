## Рязань, двор. Кофейня и первый настоящий разгон (DESIGN.md §9, §10).
##
## Двор длинный и пустой намеренно: это первое место, где можно разогнаться
## и почувствовать, что скорость набирается, а не включается.
extends Room

const HOME := "res://src/levels/ryazan/home.tscn"
const PARK := "res://src/levels/ryazan/park.tscn"


func _define() -> void:
	room_id = "ryazan_yard"
	room_title = "Двор"

	bounds(0, 0, 56, 22)

	block(0, 18, 56, 4)
	block(0, 0, 56, 2)
	block(0, 2, 1, 16)
	block(55, 2, 1, 16)

	# Длинная прямая посередине — под разгон. Препятствия только по краям.
	block(6, 15, 3, 1)
	block(11, 12, 3, 1)
	block(46, 15, 4, 1)
	block(50, 11, 4, 1)

	# Скамейка: невысокий выступ, который сбивает разгон, если не прыгнуть.
	block(30, 17, 1, 1)

	spawn("start", 5, 18)
	spawn("west", 5, 18)
	spawn("east", 51, 18)

	coffee(9, 18, "ryazan_yard", "Рязань", "капучино на овсяном")

	# Осколок наверху слева: чтобы забрать, надо заметить лестницу.
	shard(12, 12, "ryazan_02", "Двор")

	dialogue(20, 18, "ryazan_yard_pinky", "Пинки")

	door(2, 18, HOME, "east")
	door(54, 18, PARK, "west")
