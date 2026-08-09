## Скример «Зеркало» (CONCEPT_3D.md, скример №7).
##
## Отражение начинает отставать на долю секунды. Больше не происходит
## ничего: ни звука, ни движения, ни фигуры за спиной. Расчёт на то,
## что игрок сначала не поймёт, что не так, а потом поймёт.
##
## Разрядка здесь тише всех остальных — отражение просто догоняет
## оригинал, и Пинки делает вид, что не заметила.
extends Scare

const DELAY := 0.45
const PUNCHLINE := "Пинки: что? я ничего не видела."

## Зеркало, которым скример управляет. Задаётся до добавления в дерево:
## через NodePath не выходит — путь пришлось бы выставлять после add_child,
## то есть уже после _ready, и скример оставался бы без зеркала.
var mirror: Mirror

var _mirror: Mirror


func _ready() -> void:
	id = "mirror"
	trigger_size = Vector3(2.6, 2.2, 2.6)
	# Держим отставание дольше обычного: эффект работает, только если
	# игрок успеет усомниться, показалось ему или нет.
	strike_time = 5.0
	super._ready()

	_mirror = mirror


func _strike() -> void:
	if _mirror == null:
		return
	_mirror.delay = DELAY


func _resolve() -> void:
	if _mirror == null:
		return
	# Отражение догоняет плавно: резкий скачок обратно выглядел бы
	# как сбой, а не как шутка.
	var tween := create_tween()
	tween.tween_property(_mirror, "delay", 0.0, 1.2)
	await tween.finished
	print("[%s]" % PUNCHLINE)
