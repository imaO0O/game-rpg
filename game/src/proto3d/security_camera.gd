## Камера наблюдения (CONCEPT_3D.md).
##
## Их развесил по дому Зейд. Каждая — точка обзора, которую можно
## вывести на монитор в его комнате. Переворот ролей здесь буквальный:
## следил он, а смотреть будет она.
##
## Картинка рендерится только когда камера выбрана: держать полдюжины
## включённых видов одновременно — верный способ уронить кадры.
class_name SecurityCamera
extends Node3D

## Подпись на мониторе. Не «камера 3», а место — так понятнее, где это.
@export var label := ""
@export var resolution := Vector2i(480, 360)
@export var fov := 78.0

var _viewport: SubViewport
var _camera: Camera3D
var _body: Node3D
var _active := false


func _ready() -> void:
	add_to_group("security_camera")

	_viewport = SubViewport.new()
	_viewport.size = resolution
	# По умолчанию не рисуем вовсе: включится, когда выберут.
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)

	# Мир берём у корневого окна, а не у своего родителя: SubViewport
	# иначе заводит собственный пустой World3D и снимает чёрный кадр.
	# Присваивать надо после add_child — до него узел не в дереве.
	_viewport.world_3d = get_tree().root.world_3d

	_camera = Camera3D.new()
	_camera.fov = fov
	_camera.current = true
	# Вложенное окно не наследует настройки основного, поэтому без своего
	# окружения картинка уходит в чёрноту: нет ни тонирования, ни рассеянного
	# света. Заодно даём камере видеть в темноте лучше глаза — она и должна.
	_camera.environment = _build_environment()
	_viewport.add_child(_camera)


func _build_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.19, 0.22)
	# Втрое ярче комнатного: дешёвая камера тянет усиление до предела,
	# отсюда и зерно на записи.
	env.ambient_light_energy = 1.1
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.5
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.35
	env.adjustment_contrast = 1.2
	return env

	_build_body()


## Корпус: коробочка с объективом и красным огоньком. Камеру должно
## быть видно в комнате — иначе непонятно, откуда берётся картинка.
func _build_body() -> void:
	_body = Node3D.new()
	add_child(_body)

	var case := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.1, 0.09, 0.16)
	case.mesh = box

	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.09, 0.09, 0.1)
	dark.roughness = 0.6
	case.material_override = dark
	_body.add_child(case)

	var lens := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.028
	cyl.bottom_radius = 0.028
	cyl.height = 0.04
	cyl.radial_segments = 12
	lens.mesh = cyl
	lens.rotation.x = PI * 0.5
	lens.position = Vector3(0.0, 0.0, -0.09)

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.02, 0.02, 0.03)
	glass.roughness = 0.1
	glass.metallic = 0.8
	lens.material_override = glass
	_body.add_child(lens)

	# Огонёк записи: единственное, что выдаёт камеру в темноте.
	var led := OmniLight3D.new()
	led.light_color = Color(1.0, 0.15, 0.1)
	led.light_energy = 0.12
	led.omni_range = 0.5
	led.shadow_enabled = false
	led.position = Vector3(0.045, 0.035, -0.05)
	_body.add_child(led)


## Смотреть в точку. Удобнее, чем выставлять углы руками.
func aim_at(target: Vector3) -> void:
	look_at(target, Vector3.UP)


func texture() -> ViewportTexture:
	return _viewport.get_texture()


## Включает рендер. Выключенная камера не тратит ничего.
func set_active(value: bool) -> void:
	if _active == value:
		return
	_active = value
	_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
	)


func is_active() -> bool:
	return _active
