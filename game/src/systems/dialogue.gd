## Обёртка над Dialogic (DESIGN.md §12, §16).
##
## Своего диалогового движка мы не пишем — но и звать Dialogic напрямую
## из мира не хотим: таймлайны с настоящими репликами лежат в private/
## и в репозитории их нет. Без них игра обязана оставаться играбельной,
## поэтому здесь же живёт заглушка.
class_name Dialogue
extends RefCounted

## Таймлайны с настоящими репликами. Каталог в .gitignore.
const TIMELINE_DIR := "res://private/timelines"


static func path_for(timeline_name: String) -> String:
	return "%s/%s.dtl" % [TIMELINE_DIR, timeline_name]


static func exists(timeline_name: String) -> bool:
	return ResourceLoader.exists(path_for(timeline_name))


## Запускает таймлайн и ждёт его конца. Возвращает false, если реплик
## ещё нет — вызывающий код тогда показывает заглушку.
static func play(timeline_name: String) -> bool:
	if not exists(timeline_name):
		return false

	var timeline: Resource = load(path_for(timeline_name))
	if timeline == null:
		push_warning("Таймлайн есть, но не грузится: %s" % timeline_name)
		return false

	Dialogic.start(timeline)
	await Dialogic.timeline_ended
	return true
