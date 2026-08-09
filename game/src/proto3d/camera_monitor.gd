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

var _screen: MeshInstance3D
var _material: ShaderMaterial
var _cameras: Array[SecurityCamera] = []
var _index := -1
var _glitch := 0.0


func _ready() -> void:
	prompt_text = "переключить камеру"
	build_target(0.6, Vector3(0.0, 0.0, 0.0))
	_build_screen()

	# Камеры появляются в дереве в том же кадре, поэтому ищем их
	# после того, как сцена достроится.
	_collect_cameras.call_deferred()


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
	_material.set_shader_parameter("feed", camera.texture())

	# Переключение всегда со сбоем сигнала — так оно ощущается
	# как переключение, а не как подмена картинки.
	_glitch = 0.85
	switched.emit(camera)


## Сколько камер нашлось. Нужно проверкам.
func camera_count() -> int:
	return _cameras.size()


func current_camera() -> SecurityCamera:
	if _index < 0 or _index >= _cameras.size():
		return null
	return _cameras[_index]


## Резкий сбой сигнала. Скримеры дёргают его, когда в кадре
## что-то происходит.
func glitch_now(strength := 1.0) -> void:
	_glitch = maxf(_glitch, strength)
