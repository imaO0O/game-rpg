## Способности (DESIGN.md §6).
##
## Каждая — не абстрактный апгрейд, а конкретная черта, у которой есть
## буквальная механика и правдивое значение. Порядок в enum совпадает
## с порядком получения по сюжету.
class_name Abilities
extends RefCounted

enum Kind {
	PARSELTONGUE,  ## Змееуст — Рязань, пролог
	SLIPSTREAM,    ## Слипстрим — Сочи, автодром
	PIT_STOP,      ## Пит-стоп — Москва, вокзалы
	STALK,         ## Сталк-режим — ночная Рязань, дом Зейда
	WET_TYRES,     ## Мокрая резина — Петербург, каналы
}

const TITLE := {
	Kind.PARSELTONGUE: "Змееуст",
	Kind.SLIPSTREAM: "Слипстрим",
	Kind.PIT_STOP: "Пит-стоп",
	Kind.STALK: "Сталк-режим",
	Kind.WET_TYRES: "Мокрая резина",
}

const HINT := {
	Kind.PARSELTONGUE: "Змеи слушаются. Запертые двери — больше не проблема.",
	Kind.SLIPSTREAM: "Рывок в воздухе. Пропасти стали короче.",
	Kind.PIT_STOP: "Сеть кофеен открыта. Дорога назад больше не занимает время.",
	Kind.STALK: "Видно то, что прячется за стенами.",
	Kind.WET_TYRES: "Сцепление на воде. Дождь больше не сбивает с линии.",
}

## Цвет способности — им же красятся её гейты, чтобы связь читалась без слов.
const COLOR := {
	Kind.PARSELTONGUE: Color("4ea36b"),
	Kind.SLIPSTREAM: Color("d8b13a"),
	Kind.PIT_STOP: Color("c8ccd2"),
	Kind.STALK: Color("8a4ec4"),
	Kind.WET_TYRES: Color("3f8fd0"),
}


static func title(kind: Kind) -> String:
	return TITLE.get(kind, "?")


static func hint(kind: Kind) -> String:
	return HINT.get(kind, "")


static func color(kind: Kind) -> Color:
	return COLOR.get(kind, Color.WHITE)
