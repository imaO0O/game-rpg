## Кофемашина — точка покоя (CONCEPT_3D.md, «Механики»).
##
## Делает три вещи разом: сохраняет игру, заряжает фонарь и на несколько
## секунд включает нормальный свет. Последнее важнее первых двух:
## в хорроре передышка должна ощущаться, а не отмечаться в меню.
##
## В каждой комнате свой напиток — настоящий, тот, что она там пила.
class_name CoffeePoint
extends Interactable

signal used(id: String)

const REST_LIGHT_TIME := 6.0

@export var id := ""
@export var city := ""
@export var drink := ""

var _light: OmniLight3D
var _steam: GPUParticles3D
var _resting := false


func _ready() -> void:
	prompt_text = drink if not drink.is_empty() else "отдохнуть"

	build_target(0.55, Vector3(0.0, 0.45, 0.0))

	# Тёплый огонёк над машиной: точку покоя должно быть видно
	# с другого конца комнаты, иначе её просто не найдут.
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.82, 0.55)
	_light.light_energy = 0.35
	_light.omni_range = 2.2
	_light.shadow_enabled = false
	_light.position = Vector3(0.0, 0.55, 0.0)
	add_child(_light)

	_steam = _build_steam()
	add_child(_steam)


func _process(delta: float) -> void:
	var target := 0.35
	if is_looked_at():
		target = 0.6
	if _resting:
		target = 2.4
	_light.light_energy = lerpf(_light.light_energy, target, 1.0 - exp(-4.0 * delta))


func prompt() -> String:
	return "выпить %s" % prompt_text if not drink.is_empty() else prompt_text


func interact() -> bool:
	if _resting:
		return false

	Game.set_checkpoint(id, scene_file_path, Vector2.ZERO)
	Game.register_stop(id, {"id": id, "city": city, "drink": drink})
	Game.save_game()

	_recharge_player()
	_rest()
	used.emit(id)
	return true


## Передышка: свет разгорается, пар идёт гуще, потом всё возвращается.
func _rest() -> void:
	_resting = true
	_steam.amount_ratio = 1.0

	await get_tree().create_timer(REST_LIGHT_TIME).timeout

	_resting = false
	_steam.amount_ratio = 0.35


func _recharge_player() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if node.has_method("recharge"):
			node.recharge()


func _build_steam() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = 60
	particles.lifetime = 2.6
	particles.amount_ratio = 0.35
	particles.position = Vector3(0.0, 0.44, -0.06)
	particles.visibility_aabb = AABB(Vector3(-0.4, 0, -0.4), Vector3(0.8, 1.2, 0.8))

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.02
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 8.0
	mat.gravity = Vector3(0.0, 0.06, 0.0)
	mat.initial_velocity_min = 0.06
	mat.initial_velocity_max = 0.16
	mat.scale_min = 0.4
	mat.scale_max = 1.1
	particles.process_material = mat

	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.06, 0.06)
	var steam_mat := StandardMaterial3D.new()
	steam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	steam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	steam_mat.albedo_color = Color(1.0, 0.97, 0.93, 0.09)
	steam_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = steam_mat
	particles.draw_pass_1 = mesh

	return particles
