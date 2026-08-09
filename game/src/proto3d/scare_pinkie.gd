## Скример «Пинки» (CONCEPT_3D.md, скример №2).
##
## Оборачиваешься — она вплотную к лицу, с шариком, орёт. Разрядка
## мгновенная: «Ой. Я думала, ты знала, что я тут.»
##
## Единственный скример, который срабатывает от поворота головы,
## а не от шага. Поэтому он и работает: игрок сам подставляется,
## и винить некого.
extends Scare

const PUNCHLINE := "Пинки: ой. я думала, ты знала, что я тут."
const SHOUT := "СЮРПРИЗ!"
## Насколько близко к лицу. Ближе — фигура не помещается в кадр
## и читается цветным пятном, дальше — перестаёт пугать.
const DISTANCE := 0.85
const IN_FACE_TIME := 0.45

var _pinkie: Node3D
var _victim: Node3D
var _shown := 0.0
var _hit_sound: AudioStreamPlayer3D


func _ready() -> void:
	id = "pinkie"
	trigger_size = Vector3(2.4, 2.2, 2.4)
	strike_time = 1.5
	super._ready()

	_pinkie = _build_pinkie()
	_pinkie.visible = false
	add_child(_pinkie)

	_hit_sound = _sound("scare_hit", -6.0)
	add_child(_hit_sound)


func _process(delta: float) -> void:
	if _shown <= 0.0:
		return

	_shown = maxf(0.0, _shown - delta)

	# Пока висит перед лицом — покачивается, будто прыгает на месте.
	if _pinkie.visible and _victim != null:
		var bounce := absf(sin(Time.get_ticks_msec() * 0.012)) * 0.06
		_pinkie.position.y = _victim.global_position.y - 0.85 + bounce

	if _shown <= 0.0:
		_pinkie.visible = false


func _strike() -> void:
	_victim = _find_player()
	if _victim == null:
		return

	# Ставим прямо по направлению взгляда, вплотную.
	var camera := _find_camera(_victim)
	var forward := -_victim.global_transform.basis.z
	if camera != null:
		forward = -camera.global_transform.basis.z

	forward.y = 0.0
	forward = forward.normalized()

	_pinkie.global_position = _victim.global_position + forward * DISTANCE
	_pinkie.position.y = _victim.global_position.y - 0.85
	_pinkie.look_at(_victim.global_position, Vector3.UP)
	_pinkie.visible = true
	_shown = IN_FACE_TIME

	_hit_sound.play()
	print("[Пинки] %s" % SHOUT)


func _resolve() -> void:
	_pinkie.visible = false
	_shown = 0.0
	print("[%s]" % PUNCHLINE)


func _build_pinkie() -> Node3D:
	var root := Node3D.new()

	var path := "res://assets/models/figure.glb"
	if ResourceLoader.exists(path):
		var scene: PackedScene = load(path)
		var body := scene.instantiate()

		# Единственная яркая вещь во всём доме — и это правильно:
		# Пинки здесь чужеродна настолько, насколько возможно.
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.96, 0.42, 0.72)
		mat.roughness = 0.65
		mat.emission_enabled = true
		mat.emission = Color(0.6, 0.2, 0.38)
		mat.emission_energy_multiplier = 0.35
		_apply(body, mat)
		root.add_child(body)

	# Шарик на нитке: без него это просто розовый силуэт.
	var balloon := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.36
	balloon.mesh = sphere
	balloon.position = Vector3(0.34, 2.05, 0.0)

	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.92, 0.24, 0.3)
	rubber.roughness = 0.25
	balloon.material_override = rubber
	root.add_child(balloon)

	var string := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.004
	cyl.bottom_radius = 0.004
	cyl.height = 0.55
	cyl.radial_segments = 5
	string.mesh = cyl
	string.position = Vector3(0.34, 1.6, 0.0)
	string.material_override = rubber
	root.add_child(string)

	return root


func _find_player() -> Node3D:
	for node in get_tree().get_nodes_in_group("player"):
		if node is Node3D:
			return node
	return null


func _find_camera(node: Node) -> Camera3D:
	if node is Camera3D:
		return node
	for child in node.get_children():
		var found := _find_camera(child)
		if found != null:
			return found
	return null


func _apply(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child in node.get_children():
		_apply(child, material)
