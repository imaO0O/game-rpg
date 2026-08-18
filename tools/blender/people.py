"""Генерация человеческих фигур через Skin modifier.

Собирать человека из отдельных коробок и конусов — тупик: получается
набор деталей, а не тело. Здесь другой подход, тот же, каким делают
базовую форму вручную:

  1. Задаётся скелет — вершины и рёбра, как палочная схема человека.
  2. Skin modifier обтягивает его цельной оболочкой, толщина задаётся
     радиусом на каждой вершине: шире в груди, уже в запястье.
  3. Subdivision Surface сглаживает результат.

На выходе — одна связная сетка с непрерывной поверхностью, а не
слипшиеся примитивы. Форма правится числами в таблице скелета:
изменить пропорции значит поправить пару радиусов, а не пересобирать
модель.

Запуск:
    blender --background --python tools/blender/people.py
"""

import bpy
import math
import os

OUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "game", "assets", "models",
)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.objects, bpy.data.materials):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def build_skinned(name, joints, bones, subdiv=2):
    """Строит тело по скелету.

    joints: список (позиция, радиус_вширь, радиус_вглубь). Разные радиусы
    по осям дают овальное сечение: у человека ни одна часть тела
    не круглая в сечении, и круглые конечности сразу читаются трубами.

    bones: пары индексов — что с чем соединено.
    """
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)

    coords = [j[0] for j in joints]
    mesh.from_pydata(coords, bones, [])
    mesh.update()

    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)

    skin = obj.modifiers.new(name="Skin", type="SKIN")
    skin.use_smooth_shade = True

    # Радиусы задаются после добавления модификатора: слой skin_vertices
    # появляется только вместе с ним.
    layer = obj.data.skin_vertices[0].data
    for index, joint in enumerate(joints):
        layer[index].radius = (joint[1], joint[2])

    # Корневая вершина определяет, откуда растёт оболочка. Берём таз:
    # от него расходятся и ноги, и корпус.
    layer[0].use_root = True

    if subdiv > 0:
        sub = obj.modifiers.new(name="Subdiv", type="SUBSURF")
        sub.levels = subdiv
        sub.render_levels = subdiv

    bpy.ops.object.modifier_apply(modifier=skin.name)
    if subdiv > 0:
        bpy.ops.object.modifier_apply(modifier="Subdiv")

    return obj


def add_head(obj, centre, radius, squash, tilt):
    """Голова отдельной сферой: Skin заканчивает цепочку коробкой,
    а череп — единственное место, где нужна именно сфера."""
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=radius, location=centre, segments=24, ring_count=16
    )
    head = bpy.context.active_object
    head.name = "head"
    head.scale = squash
    head.rotation_euler = tilt
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    head.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.join()
    return obj


def finish(obj, name):
    bpy.context.view_layer.objects.active = obj
    obj.name = name

    if hasattr(bpy.ops.object, "shade_auto_smooth"):
        bpy.ops.object.shade_auto_smooth(angle=math.radians(50))
    else:
        bpy.ops.object.shade_smooth()

    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)

    # Blender считает вверхом Z, glTF и Godot — Y. Поворачиваем сами
    # и отключаем конверсию экспортёра: одно преобразование вместо двух.
    obj.rotation_euler = (-math.pi / 2, 0, 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)

    path = os.path.join(OUT_DIR, "%s.glb" % name)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=False,
    )
    print("сохранено: %s (вершин %d)" % (path, len(obj.data.vertices)))


# Связи скелета одинаковы у всех фигур: это человек, а не разные
# существа. Отличаются только координаты и толщины.
BONES = [
    (0, 1), (1, 2), (2, 3), (3, 4),
    (2, 5), (5, 6), (6, 7),
    (2, 8), (8, 9), (9, 10),
    (0, 11), (11, 12), (12, 13), (13, 14),
    (0, 15), (15, 16), (16, 17), (17, 18),
]


def make_zade():
    """Зейд: обычный человек, слегка ссутуленный.

    Пропорции человеческие: голова укладывается в рост примерно семь
    с половиной раз, размах рук близок к росту, локоть на уровне пояса,
    кисть — на середине бедра. Это то, что глаз проверяет неосознанно,
    и именно на этом ломались прежние модели.
    """
    clear_scene()

    joints = [
        ((0.0, 0.0, 0.98), 0.13, 0.10),      # 0 таз — корень
        ((0.0, -0.01, 1.18), 0.14, 0.11),    # 1 поясница
        ((0.0, -0.03, 1.38), 0.17, 0.12),    # 2 грудь
        ((0.0, -0.05, 1.52), 0.13, 0.10),    # 3 основание шеи
        ((0.0, -0.06, 1.62), 0.055, 0.055),  # 4 шея

        ((-0.17, -0.04, 1.48), 0.06, 0.06),  # 5 плечо
        ((-0.22, 0.0, 1.19), 0.05, 0.05),    # 6 локоть на уровне пояса
        ((-0.24, 0.03, 0.94), 0.038, 0.038), # 7 запястье

        ((0.17, -0.04, 1.49), 0.06, 0.06),
        ((0.21, -0.02, 1.2), 0.05, 0.05),
        ((0.23, 0.01, 0.95), 0.038, 0.038),

        ((-0.09, 0.0, 0.92), 0.085, 0.085),  # 11 бедро
        ((-0.1, 0.01, 0.52), 0.065, 0.065),  # 12 колено
        ((-0.11, -0.01, 0.07), 0.048, 0.048),# 13 щиколотка
        ((-0.11, -0.09, 0.03), 0.05, 0.06),  # 14 стопа вперёд

        ((0.09, 0.0, 0.92), 0.085, 0.085),
        ((0.1, 0.0, 0.52), 0.065, 0.065),
        ((0.1, 0.01, 0.07), 0.048, 0.048),
        ((0.1, -0.07, 0.03), 0.05, 0.06),
    ]

    body = build_skinned("zade_body", joints, BONES)
    add_head(body, (0.0, -0.07, 1.74), 0.105, (0.88, 1.0, 1.15), (math.radians(6), 0, 0))
    finish(body, "zade")


def make_figure():
    """Фигура для скримеров: человек, у которого всё чуть неправильно.

    Скелет тот же, что у Зейда, — иначе она перестала бы читаться
    человеком, а нужно именно это. Отличия только в числах: рост под
    два метра, кисти ниже колен, шея вытянута, плечи на разной высоте,
    голова склонена набок.

    Игрок не считает эти пропорции сознательно. Он просто поймёт,
    что перед ним что-то неправильное, и не сможет объяснить, что
    именно, — на этом скример и держится.
    """
    clear_scene()

    joints = [
        ((0.0, 0.0, 1.06), 0.1, 0.075),
        ((0.0, -0.02, 1.3), 0.105, 0.08),
        ((0.01, -0.05, 1.54), 0.14, 0.085),
        ((0.0, -0.07, 1.7), 0.1, 0.07),
        ((0.02, -0.09, 1.84), 0.045, 0.045),   # шея заметно длиннее

        ((-0.16, -0.06, 1.66), 0.05, 0.05),    # плечи на разной высоте
        ((-0.23, 0.0, 1.28), 0.042, 0.042),
        ((-0.28, 0.05, 0.82), 0.03, 0.03),     # кисть ниже колена

        ((0.16, -0.06, 1.71), 0.048, 0.048),
        ((0.22, -0.03, 1.32), 0.04, 0.04),
        ((0.26, -0.02, 0.86), 0.028, 0.028),

        ((-0.08, 0.0, 1.0), 0.07, 0.07),
        ((-0.1, 0.02, 0.55), 0.052, 0.052),
        ((-0.12, -0.02, 0.06), 0.036, 0.036),
        ((-0.12, -0.1, 0.028), 0.042, 0.055),

        ((0.08, 0.0, 1.0), 0.07, 0.07),
        ((0.09, -0.01, 0.55), 0.052, 0.052),
        ((0.1, 0.02, 0.06), 0.036, 0.036),
        ((0.1, -0.06, 0.028), 0.042, 0.055),
    ]

    body = build_skinned("figure_body", joints, BONES)
    add_head(
        body,
        (0.03, -0.11, 1.96), 0.098,
        (0.82, 1.0, 1.24),
        (math.radians(12), 0, math.radians(14)),
    )
    finish(body, "figure")


def main():
    make_zade()
    make_figure()
    print("готово: фигуры в %s" % OUT_DIR)


if __name__ == "__main__":
    main()
