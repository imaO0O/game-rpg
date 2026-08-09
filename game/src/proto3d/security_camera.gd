## Камера наблюдения (CONCEPT_3D.md).
##
## Их развесил по дому Зейд. Каждая — точка обзора, которую можно
## вывести на монитор в его комнате. Переворот ролей здесь буквальный:
## следил он, а смотреть будет она.
##
## Сама камера ничего не рендерит: она только помнит, где стоит и куда
## смотрит. Картинку снимает монитор, переставляя в свою единственную
## камеру трансформ выбранной точки. Так вместо полудюжины окон
## рендерится одно, а текстура принадлежит тому, кто её показывает —
## иначе она не доходит до чужого материала.
class_name SecurityCamera
extends Node3D

## Подпись на мониторе. Не «камера 3», а место — так понятнее, где это.
@export var label := ""
@export var fov := 78.0

var _body: Node3D
var _led: OmniLight3D
var _active := false


func _ready() -> void:
	add_to_group("security_camera")
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
	_led = OmniLight3D.new()
	_led.light_color = Color(1.0, 0.15, 0.1)
	_led.light_energy = 0.12
	_led.omni_range = 0.5
	_led.shadow_enabled = false
	_led.position = Vector3(0.045, 0.035, -0.05)
	_body.add_child(_led)


## Смотреть в точку. Удобнее, чем выставлять углы руками.
func aim_at(target: Vector3) -> void:
	look_at(target, Vector3.UP)


## Точка съёмки для монитора: откуда и куда смотреть.
func view_transform() -> Transform3D:
	return global_transform


## Выбрана ли сейчас. Огонёк на выбранной горит ярче — мелочь,
## по которой видно, какая камера смотрит прямо сейчас.
func set_active(value: bool) -> void:
	if _active == value:
		return
	_active = value
	if _led != null:
		_led.light_energy = 0.32 if value else 0.12


func is_active() -> bool:
	return _active
