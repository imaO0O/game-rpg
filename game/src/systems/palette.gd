## Палитра проекта (DESIGN.md §13).
##
## Мир зелёно-серебряный — Слизерин. Катя красная — Ferrari.
## Единственное красное пятно в зелёном мире всегда читается на любом фоне:
## это и характер, и решение задачи видимости персонажа.
class_name Palette
extends RefCounted

const BACKGROUND := Color("081410")
const BLOCK := Color("1e3a2c")
const EDGE := Color("3d7359")
const SILVER := Color("c7ccd1")
const SILVER_DIM := Color("7d8891")

## Игрок и всё, что относится к скорости.
const FERRARI := Color("dc0000")

const SHARD := Color("e8d9a0")
const COFFEE := Color("c8a06a")
const WATER := Color("2a5a7a")

## Сочи: то же семейство, но теплее и светлее — солнце и море.
const SOCHI_BACKGROUND := Color("0d2028")
const SOCHI_BLOCK := Color("1d4150")
const SOCHI_EDGE := Color("3a7a8c")
const SEA := Color("15414f")
const SUN := Color("d9a854")

## Разметка трассы.
const KERB := Color("b03535")

## Петербург: гранит, вода и дождь. Самая холодная палитра в игре.
const SPB_BACKGROUND := Color("0b1117")
const SPB_BLOCK := Color("212a32")
const SPB_EDGE := Color("47555f")
const SPB_WATER := Color("18333f")
const RAIN := Color("8fa8b8")

## Ночная Рязань: та же зелень, что в прологе, но обесцвеченная.
## Узнать место игрок должен по форме, а не по цвету.
const NIGHT_BACKGROUND := Color("06080a")
const NIGHT_BLOCK := Color("141a1c")
const NIGHT_EDGE := Color("263038")
const WINDOW_LIGHT := Color("c9a05a")

## Москва: камень и лампы. Суше Рязани и холоднее Сочи.
const MOSCOW_BACKGROUND := Color("13151b")
const MOSCOW_BLOCK := Color("2b2e39")
const MOSCOW_EDGE := Color("4d5464")
const LAMP := Color("d8b878")
const RAIL := Color("3a3f4d")
