## Скример «Осколок-беглец» (CONCEPT_3D.md, скример №8).
##
## Тянешься за фотографией — она улетает по коридору и ждёт за углом.
## Ещё раз. И ещё. На четвёртый раз сдаётся и даёт себя взять.
##
## Единственный скример, который не пугает вовсе: он раздражает,
## а потом становится смешным. Нужен затем, чтобы игрок перестал
## ждать от каждой странности удара — иначе к середине дома он
## перестанет реагировать на всё подряд.
extends Scare

const PUNCHLINE := "Пинки: ладно-ладно. забирай."
## Сколько раз убежит, прежде чем дастся.
const ESCAPES := 3
const FLIGHT_SPEED := 4.5

var _memory: MemoryObject
var _escapes_left := ESCAPES
var _flying := false
var _target := Vector3.ZERO
## Куда убегать по очереди. Последняя точка — тупик, из которого
## деваться уже некуда.
var _spots: Array[Vector3] = []
var _spot_index := 0
var _gave_up := false


func _ready() -> void:
	id = "runaway"
	trigger_size = Vector3.ZERO
	strike_time = 0.6
	super._ready()


## Привязка к осколку. Ставится до добавления в дерево.
func attach(memory: MemoryObject, spots: Array[Vector3]) -> void:
	_memory = memory
	_spots = spots
	if _memory != null:
		_memory.escape_check = _on_escape_requested


func _process(delta: float) -> void:
	if not _flying or _memory == null or not is_instance_valid(_memory):
		return

	_memory.global_position = _memory.global_position.move_toward(_target, FLIGHT_SPEED * delta)
	if _memory.global_position.distance_to(_target) < 0.05:
		_flying = false


## Осколок спрашивает разрешения перед тем, как дать себя взять.
## Возвращаем true, если брать пока нельзя.
func _on_escape_requested() -> bool:
	if _escapes_left <= 0:
		return false

	_escapes_left -= 1
	fire()
	return true


func _strike() -> void:
	if _memory == null or _spots.is_empty():
		return

	_target = _spots[_spot_index % _spots.size()]
	_spot_index += 1
	_flying = true

	# Скример одноразовый по флагу, но убегать должен несколько раз,
	# поэтому взводим его обратно вручную.
	if _escapes_left > 0:
		rearm()


func _resolve() -> void:
	if _escapes_left > 0 or _gave_up:
		return
	# Реплика ровно одна: каждый побег вызывает разрядку, и без флага
	# последняя фраза звучала бы дважды подряд.
	_gave_up = true
	print("[%s]" % PUNCHLINE)
