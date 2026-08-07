## Отладочный оверлей. F1 — показать/скрыть, R — вернуться на старт.
##
## Нужен ровно на этапе подбора ощущения движения: без цифр параметры
## в MovementConfig крутятся вслепую.
extends CanvasLayer

@export var player: Player

@onready var _stats: Label = $Panel/Stats


func _ready() -> void:
	visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		visible = not visible


func _process(_delta: float) -> void:
	if not visible or player == null:
		return

	var s := player.debug_state()
	var lines := [
		"скорость   %7.1f  (макс %.0f)" % [s.speed, s.max_speed],
		"падение    %7.1f" % s.fall,
		"разгон     %s %.2f" % [_bar(s.momentum), s.momentum],
		"кофеин     %s %.0f" % [_bar(s.caffeine / 100.0), s.caffeine],
		"",
		"прямая     %.2f с" % s.clean,
		"DRS        %s" % ("ГОТОВ" if s.drs_ready else _drs_reason(s)),
		"",
		"coyote     %.3f" % s.coyote,
		"buffer     %.3f" % s.buffer,
		"на земле   %s" % ("да" if s.on_floor else "нет"),
		"",
		"F1 — оверлей, R — на старт",
	]
	_stats.text = "\n".join(lines)


## Почему DRS недоступен — важнее, чем сам факт недоступности.
func _drs_reason(s: Dictionary) -> String:
	if s.momentum < player.config.drs_threshold:
		return "мало разгона"
	if s.clean < player.config.drs_clean_time:
		return "нет прямой"
	if s.caffeine < player.config.drs_cost:
		return "нет кофеина"
	return "перезарядка"


func _bar(ratio: float, width: int = 10) -> String:
	var filled := int(round(clampf(ratio, 0.0, 1.0) * width))
	return "[%s%s]" % ["=".repeat(filled), " ".repeat(width - filled)]
