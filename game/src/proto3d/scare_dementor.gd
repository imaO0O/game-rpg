## Скример «Дементор» (CONCEPT_3D.md, скример №9).
##
## Из пара кофемашины вырастает силуэт в балахоне. Разрядка:
## это Пинки в простыне. «Экспекто патронум, детка.»
##
## Срабатывает со второго кофе, а не с первого: первый раз игрок
## уже получил свой скример от самой машины, и два подряд в одном
## месте превратили бы точку покоя в аттракцион.
extends Scare

const PUNCHLINE := "Пинки: экспекто патронум, детка."
const RISE_TIME := 1.2
const USE_BEFORE_FIRING := 2

var _shroud: Node3D
var _coffee: CoffeePoint
var _uses := 0
var _rise := 0.0
var _base_y := 0.0


func _ready() -> void:
	id = "dementor"
	trigger_size = Vector3.ZERO
	strike_time = 2.8
	super._ready()

	_shroud = _build_shroud()
	_shroud.visible = false
	add_child(_shroud)


## Привязка к машине. Ставится до добавления в дерево.
func attach(point: CoffeePoint) -> void:
	_coffee = point
	if _coffee != null:
		_coffee.used.connect(_on_used)


func _on_used(_id: String) -> void:
	_uses += 1
	if _uses < USE_BEFORE_FIRING:
		return
	fire()


func _process(delta: float) -> void:
	if _rise <= 0.0:
		return

	_rise = maxf(0.0, _rise - delta)

	# Растёт из пара, а не появляется: скачком это читалось бы
	# как подмена модели, а нужно именно «сгущается».
	var t := 1.0 - _rise / RISE_TIME
	_shroud.position.y = _base_y - 1.5 + t * 1.5
	_shroud.scale = Vector3.ONE * lerpf(0.3, 1.0, t)


func _strike() -> void:
	if _coffee == null:
		return

	_base_y = _coffee.global_position.y + 0.4
	_shroud.global_position = _coffee.global_position + Vector3(0.0, -1.1, 0.15)
	_shroud.visible = true
	_rise = RISE_TIME

	blackout(0.25)


func _resolve() -> void:
	# Простыня спадает: балахон исчезает, а под ним ничего страшного.
	var tween := create_tween()
	tween.tween_property(_shroud, "scale", Vector3.ONE * 0.05, 0.5)
	await tween.finished

	_shroud.visible = false
	_rise = 0.0
	print("[%s]" % PUNCHLINE)


## Балахон: конус с рваным низом. Лица нет — оно и не нужно,
## вся жуть в силуэте.
func _build_shroud() -> Node3D:
	var root := Node3D.new()

	var body := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.16
	cone.bottom_radius = 0.42
	cone.height = 1.45
	cone.radial_segments = 14
	body.mesh = cone
	body.position = Vector3(0.0, 0.72, 0.0)

	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.86, 0.86, 0.84, 0.72)
	cloth.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloth.roughness = 1.0
	# Слегка светится: в темноте кухни силуэт должен читаться сам,
	# без помощи фонаря.
	cloth.emission_enabled = true
	cloth.emission = Color(0.4, 0.42, 0.45)
	cloth.emission_energy_multiplier = 0.3
	body.material_override = cloth
	root.add_child(body)

	# Капюшон.
	var hood := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.3
	hood.mesh = sphere
	hood.position = Vector3(0.0, 1.5, 0.0)
	hood.material_override = cloth
	root.add_child(hood)

	# Провал вместо лица — единственная тёмная деталь.
	var face := MeshInstance3D.new()
	var hole := SphereMesh.new()
	hole.radius = 0.11
	hole.height = 0.18
	face.mesh = hole
	face.position = Vector3(0.0, 1.48, -0.12)

	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.02, 0.02, 0.025)
	dark.roughness = 1.0
	face.material_override = dark
	root.add_child(face)

	return root
