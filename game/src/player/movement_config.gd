## Все параметры движения в одном месте.
##
## Смысл: крутить ощущение игры, не трогая код. Значения подбираются
## на полигоне (src/levels/testbed.tscn) с включённым оверлеем (F1).
class_name MovementConfig
extends Resource

@export_group("Скорость")
## Скорость без разгона — с ней игрок начинает движение.
@export var base_speed := 110.0
## Скорость на полном разгоне (momentum = 1.0).
@export var top_speed := 260.0

@export_group("Ускорение и трение")
@export var ground_accel := 1200.0
@export var ground_friction := 1400.0
@export var air_accel := 900.0
@export var air_friction := 400.0
## Во сколько раз быстрее набирается скорость при развороте.
## Без этого разворот ощущается ватным.
@export var turn_multiplier := 2.2

@export_group("Прыжок")
@export var jump_velocity := -330.0
## Множитель скорости при отпускании кнопки — даёт переменную высоту прыжка.
@export var jump_cut := 0.45
@export var gravity := 1000.0
## Падение быстрее подъёма. Ключевая вещь для «сочного» прыжка.
@export var fall_gravity_mult := 1.45
@export var max_fall_speed := 420.0
## Сколько ещё можно прыгнуть после схода с края.
@export var coyote_time := 0.1
## Насколько заранее засчитывается нажатие прыжка перед приземлением.
@export var jump_buffer := 0.15

@export_group("Momentum")
## Прирост разгона в секунду при удержании линии.
@export var momentum_gain := 0.35
## Потеря разгона в секунду при отсутствии ввода.
@export var momentum_decay := 0.5
## Разовая потеря при ударе в стену.
@export var momentum_wall_penalty := 0.6
## Разовая потеря при развороте.
@export var momentum_turn_penalty := 0.45

@export_group("DRS")
## Разгон, начиная с которого DRS вообще возможен.
@export var drs_threshold := 0.85
## Секунд без касания стен — это и есть «прямая».
@export var drs_clean_time := 1.2
@export var drs_speed := 420.0
@export var drs_duration := 0.18
## Гравитация во время рывка (доля от обычной).
@export var drs_gravity_mult := 0.15
@export var drs_cost := 18.0
## Пауза между рывками.
@export var drs_cooldown := 0.35

@export_group("Слипстрим")
## Воздушный рывок. Та же кнопка, что DRS: на земле — DRS, в воздухе — слипстрим.
@export var slipstream_speed := 300.0
@export var slipstream_duration := 0.16
## Невесомость на время рывка, иначе он не читается как рывок.
@export var slipstream_gravity_mult := 0.0
## Лёгкий подброс — чтобы рывком можно было дотянуться до площадки выше.
@export var slipstream_lift := -70.0

@export_group("Вода")
## Без Мокрой резины в воде скользко: доля от обычного трения.
@export var water_friction_mult := 0.25
## И медленнее: доля от максимальной скорости.
@export var water_speed_mult := 0.7
## Во сколько раз быстрее теряется разгон на мокром. Без этого игрок
## влетает в воду разогнанным и проскакивает её, не заметив гейта.
@export var water_momentum_decay_mult := 3.0

@export_group("Squash & stretch")
@export var squash_jump := Vector2(0.78, 1.28)
@export var squash_land := Vector2(1.32, 0.72)
## Скорость возврата к нормальной форме.
@export var squash_recover := 14.0
## Вертикальная скорость, начиная с которой приземление считается жёстким.
@export var hard_landing_speed := 320.0
