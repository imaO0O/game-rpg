## Монитор наблюдения в комнате Зейда.
##
## Показывает вид с одной из его камер. Переключение — тем же ключом
## взаимодействия: нажал, перешёл к следующей. Экран с развёрткой
## и помехами, потому что чистая картинка читается как окно в соседнюю
## комнату, а нужна именно запись — от записи ждёшь, что в кадре
## что-то мелькнёт.
class_name CameraMonitor
extends Interactable

signal switched(camera: SecurityCamera)

const SCREEN_SIZE := Vector2(0.62, 0.46)
const FEED_RESOLUTION := Vector2i(480, 360)

var _screen: MeshInstance3D
var _material: ShaderMaterial
var _cameras: Array[SecurityCamera] = []
var _index := -1
var _glitch := 0.0

## Единственное окно рендера на все камеры. Владеть им должен монитор:
## текстура вложенного окна не доходит до материала чужого узла.
var _feed_viewport: SubViewport
var _feed_camera: Camera3D


func _ready() -> void:
	prompt_text = "переключить камеру"
	build_target(0.6, Vector3(0.0, 0.0, 0.0))
	_build_feed()
	_build_screen()

	# Камеры появляются в дереве в том же кадре, поэтому ищем их
	# после того, как сцена достроится.
	_collect_cameras.call_deferred()


## Окно рендера и камера в нём. Одно на все точки обзора: переключение
## сводится к перестановке трансформа, а не к включению нового окна.
func _build_feed() -> void:
	_feed_viewport = SubViewport.new()
	_feed_viewport.size = FEED_RESOLUTION
	_feed_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_feed_viewport)

	# Мир берём у корня: иначе окно заведёт собственный пустой World3D
	# и снимет чёрный кадр. Присваивать надо после add_child.
	_feed_viewport.world_3d = get_tree().root.world_3d

	_feed_camera = Camera3D.new()
	_feed_camera.current = true
	# Дешёвая камера тянет усиление до предела — отсюда и зерно записи.
	_feed_camera.environment = _build_feed_environment()
	_feed_viewport.add_child(_feed_camera)


func _build_feed_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.19, 0.22)
	env.ambient_light_energy = 1.1
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.5
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.35
	env.adjustment_contrast = 1.2
	return env


func _process(delta: float) -> void:
	if _glitch > 0.0:
		_glitch = maxf(0.0, _glitch - delta * 1.6)
		_material.set_shader_parameter("glitch", _glitch)
		_material.set_shader_parameter("noise_amount", 0.12 + _glitch * 0.5)


func _collect_cameras() -> void:
	_cameras.clear()
	for node in get_tree().get_nodes_in_group("security_camera"):
		if node is SecurityCamera:
			_cameras.append(node)

	if _cameras.is_empty():
		push_warning("Монитор не нашёл ни одной камеры")
		return

	_show(0)


func _build_screen() -> void:
	_screen = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = SCREEN_SIZE
	_screen.mesh = quad

	_material = ShaderMaterial.new()
	_material.shader = preload("res://src/shaders/crt.gdshader")
	_material.set_shader_parameter("noise_amount", 0.12)
	_material.set_shader_parameter("scanline_amount", 0.35)
	_material.set_shader_parameter("glitch", 0.0)
	# Текстуру ставим один раз: окно своё, менять его не придётся.
	_material.set_shader_parameter("feed", _feed_viewport.get_texture())
	_screen.material_override = _material
	add_child(_screen)

	# Корпус вокруг экрана.
	var case := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(SCREEN_SIZE.x + 0.07, SCREEN_SIZE.y + 0.07, 0.09)
	case.mesh = box
	case.position = Vector3(0.0, 0.0, -0.05)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.11, 0.11, 0.12)
	mat.roughness = 0.7
	case.material_override = mat
	add_child(case)

	# Свечение экрана на стену: монитор должен освещать комнату сам.
	# Источник вынесен вперёд и вбок — стоящий вплотную светил бы
	# в собственный экран и засвечивал картинку.
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.55, 0.78, 0.72)
	glow.light_energy = 0.45
	glow.omni_range = 2.4
	glow.omni_attenuation = 2.0
	glow.shadow_enabled = false
	glow.position = Vector3(0.0, -0.35, 0.55)
	add_child(glow)


func prompt() -> String:
	if _index < 0 or _index >= _cameras.size():
		return "включить монитор"
	return "камера: %s" % _cameras[_index].label


func interact() -> bool:
	if _cameras.is_empty():
		return false
	_show((_index + 1) % _cameras.size())
	return true


func _show(index: int) -> void:
	if index == _index or _cameras.is_empty():
		return

	# Гасим прежнюю: выключенная камера ничего не рендерит.
	if _index >= 0 and _index < _cameras.size():
		_cameras[_index].set_active(false)

	_index = index
	var camera := _cameras[_index]
	camera.set_active(true)
	# Переставляем свою камеру в точку выбранной: окно одно на всех.
	_feed_camera.global_transform = camera.view_transform()
	_feed_camera.fov = camera.fov

	# Переключение всегда со сбоем сигнала — так оно ощущается
	# как переключение, а не как подмена картинки.
	_glitch = 0.85
	switched.emit(camera)


## Сколько камер нашлось. Нужно проверкам.
func camera_count() -> int:
	return _cameras.size()


## Картинка, которая сейчас на экране. Нужна проверкам: убедиться,
## что монитор показывает комнату, а не чёрный прямоугольник.
func feed_texture() -> ViewportTexture:
	return _feed_viewport.get_texture()


func current_camera() -> SecurityCamera:
	if _index < 0 or _index >= _cameras.size():
		return null
	return _cameras[_index]


## Резкий сбой сигнала. Скримеры дёргают его, когда в кадре
## что-то происходит.
func glitch_now(strength := 1.0) -> void:
	_glitch = maxf(_glitch, strength)
