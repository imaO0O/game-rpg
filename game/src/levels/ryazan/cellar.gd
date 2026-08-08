## Рязань, подвал. Здесь лежит Змееуст (DESIGN.md §6).
##
## Комната тесная и тёмная в противовес парку: способность должна
## находиться в месте, которое запоминается, а не в очередном коридоре.
extends Room

const PARK := "res://src/levels/ryazan/park.tscn"


func _define() -> void:
	room_id = "ryazan_cellar"
	room_title = "Подвал"

	bounds(0, 0, 40, 20)

	block(0, 16, 40, 4)
	block(0, 0, 40, 2)
	block(0, 2, 1, 14)
	block(39, 2, 1, 14)

	# Низкий потолок над проходом: бежать можно, прыгать нельзя.
	block(10, 13, 14, 1)

	# Ящики.
	block(6, 14, 2, 2)
	block(26, 13, 3, 1)
	block(31, 10, 4, 1)

	spawn("start", 5, 16)

	# Осколок на ящиках — по дороге, но мимо можно и пробежать.
	shard(33, 10, "ryazan_05", "Подвал")

	# Собственно Змееуст, в самом дальнем углу.
	ability(36, 16, Abilities.Kind.PARSELTONGUE)

	dialogue(30, 16, "ryazan_cellar_snake", "Змея")

	door(2, 16, PARK, "cellar")
