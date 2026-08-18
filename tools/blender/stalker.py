"""Сборка детализированной фигуры сталкера.

Модель собирается слоями, как настоящий персонаж, а не одним куском:

  1. Тело — оболочка по скелету (Skin modifier).
  2. Череп — сфера с вылепленными чертами: надбровные дуги, нос,
     скулы, подбородок. Лица как такового нет, но силуэт головы
     перестаёт быть яйцом.
  3. Куртка — отдельная оболочка поверх торса, толще тела, с полами,
     воротником и капюшоном за плечами.
  4. Штаны и ботинки — своя геометрия с подошвой и голенищем.
  5. Снаряжение — ремень, подсумки, лямки рюкзака, фонарь на плече.

Каждый слой существует отдельно и получает свой материал: кожа, ткань,
резина и металл отражают свет по-разному, и без этого разделения
фигура читается вылепленной из одного вещества.

Порядок важен: одежда строится по координатам тела, поэтому таблица
скелета — единственный источник пропорций для всех слоёв.

Запуск:
    blender --background --python tools/blender/stalker.py
"""

import bpy
import bmesh
import math
import os

OUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "game", "assets", "models",
)

# --- Пропорции ---------------------------------------------------------
# Всё строится от этих чисел. Рост 1.84, голова укладывается в него
# семь с половиной раз — обычный взрослый человек.

HIP_Z = 0.98
CHEST_Z = 1.38
NECK_Z = 1.56
HEAD_Z = 1.74
SHOULDER_X = 0.19
KNEE_Z = 0.52
ANKLE_Z = 0.09


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.objects, bpy.data.materials):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def material(name, color, roughness, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return mat


def assign(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def skinned(name, joints, bones, subdiv=2):
    """Оболочка по скелету. Радиусы задают толщину в каждой точке."""
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)

    mesh.from_pydata([j[0] for j in joints], bones, [])
    mesh.update()

    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)

    skin = obj.modifiers.new(name="Skin", type="SKIN")
    skin.use_smooth_shade = True

    layer = obj.data.skin_vertices[0].data
    for index, joint in enumerate(joints):
        layer[index].radius = (joint[1], joint[2])
    layer[0].use_root = True

    if subdiv:
        sub = obj.modifiers.new(name="Subdiv", type="SUBSURF")
        sub.levels = subdiv
        sub.render_levels = subdiv

    bpy.ops.object.modifier_apply(modifier=skin.name)
    if subdiv:
        bpy.ops.object.modifier_apply(modifier="Subdiv")

    bpy.ops.object.select_all(action="DESELECT")
    return obj


def box(name, size, location, rotation=(0, 0, 0), bevel=0.006):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    if bevel:
        mod = obj.modifiers.new(name="Bevel", type="BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(40)
        bpy.ops.object.modifier_apply(modifier=mod.name)

    bpy.ops.object.select_all(action="DESELECT")
    return obj


def tube(name, radius, depth, location, rotation=(0, 0, 0), verts=16):
    bpy.ops.mesh.primitive_cylinder_add(
        radius=radius, depth=depth, location=location, rotation=rotation, vertices=verts
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.select_all(action="DESELECT")
    return obj


def sphere(name, radius, location, scale=(1, 1, 1), rotation=(0, 0, 0), segments=24):
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=radius, location=location, segments=segments, ring_count=segments // 2
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    obj.rotation_euler = rotation
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.select_all(action="DESELECT")
    return obj


def smooth(obj, angle=45):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if hasattr(bpy.ops.object, "shade_auto_smooth"):
        bpy.ops.object.shade_auto_smooth(angle=math.radians(angle))
    else:
        bpy.ops.object.shade_smooth()
    bpy.ops.object.select_all(action="DESELECT")


# --- Этап 1: тело ------------------------------------------------------

BODY_BONES = [
    (0, 1), (1, 2), (2, 3), (3, 4),
    (2, 5), (5, 6), (6, 7),
    (2, 8), (8, 9), (9, 10),
    (0, 11), (11, 12), (12, 13),
    (0, 14), (14, 15), (15, 16),
]


def build_body():
    """Голое тело. Поверх него строится всё остальное, поэтому оно
    намеренно тоньше готовой фигуры: одежда добавит объём."""
    joints = [
        ((0.0, 0.0, HIP_Z), 0.115, 0.09),
        ((0.0, -0.01, 1.18), 0.12, 0.095),
        ((0.0, -0.03, CHEST_Z), 0.15, 0.105),
        ((0.0, -0.05, NECK_Z), 0.085, 0.078),
        ((0.0, -0.06, 1.64), 0.055, 0.053),

        ((-SHOULDER_X, -0.04, 1.48), 0.055, 0.055),
        ((-0.225, 0.0, 1.19), 0.045, 0.045),
        ((-0.245, 0.03, 0.93), 0.034, 0.034),

        ((SHOULDER_X, -0.04, 1.49), 0.055, 0.055),
        ((0.22, -0.02, 1.2), 0.045, 0.045),
        ((0.24, 0.01, 0.94), 0.034, 0.034),

        ((-0.09, 0.0, 0.92), 0.08, 0.08),
        ((-0.1, 0.01, KNEE_Z), 0.06, 0.06),
        ((-0.11, -0.01, ANKLE_Z), 0.042, 0.045),

        ((0.09, 0.0, 0.92), 0.08, 0.08),
        ((0.1, 0.0, KNEE_Z), 0.06, 0.06),
        ((0.1, 0.01, ANKLE_Z), 0.042, 0.045),
    ]
    body = skinned("body", joints, BODY_BONES)
    smooth(body)
    return body


# --- Этап 2: череп -----------------------------------------------------

def build_head():
    """Череп с чертами.

    Лица нет и не будет — оно потребовало бы скульптинга. Но силуэт
    головы держится на четырёх вещах, и все они лепятся объёмами:
    затылок, надбровные дуги, нос и линия челюсти. Без них голова
    остаётся яйцом, и никакой свет этого не спасёт.
    """
    parts = []

    # Черепная коробка: вытянута назад, а не идеально круглая.
    skull = sphere("skull", 0.098, (0.0, -0.06, HEAD_Z), (0.94, 1.12, 1.16))
    parts.append(skull)

    # Затылок.
    parts.append(sphere("occiput", 0.072, (0.0, 0.01, HEAD_Z - 0.01), (1.0, 0.9, 0.92)))

    # Надбровные дуги — то, что даёт глазницам тень.
    parts.append(box("brow", (0.15, 0.045, 0.022), (0.0, -0.135, HEAD_Z + 0.028),
                     (math.radians(-8), 0, 0), bevel=0.008))

    # Нос: спинка и кончик.
    parts.append(box("nose_bridge", (0.028, 0.05, 0.075), (0.0, -0.145, HEAD_Z - 0.005),
                     (math.radians(12), 0, 0), bevel=0.006))
    parts.append(sphere("nose_tip", 0.022, (0.0, -0.163, HEAD_Z - 0.038), (1.0, 1.1, 0.85)))

    # Скулы.
    for side in (-1, 1):
        parts.append(sphere("cheek", 0.042, (side * 0.062, -0.115, HEAD_Z - 0.045),
                            (0.9, 0.8, 0.7)))

    # Челюсть и подбородок: линия челюсти — половина узнаваемости
    # силуэта в профиль.
    parts.append(box("jaw", (0.115, 0.1, 0.055), (0.0, -0.09, HEAD_Z - 0.082),
                     (math.radians(-6), 0, 0), bevel=0.018))
    parts.append(sphere("chin", 0.032, (0.0, -0.128, HEAD_Z - 0.092), (1.0, 0.9, 0.8)))

    # Уши.
    for side in (-1, 1):
        parts.append(sphere("ear", 0.028, (side * 0.098, -0.045, HEAD_Z - 0.012),
                            (0.35, 0.75, 1.0)))

    head = join(parts, "head")
    smooth(head, 50)
    return head


def join(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    result = bpy.context.active_object
    result.name = name
    bpy.ops.object.select_all(action="DESELECT")
    return result


# --- Этап 3: куртка ----------------------------------------------------

def build_jacket():
    """Куртка: оболочка поверх торса плюс полы, воротник и капюшон.

    Радиусы заметно больше телесных — одежда не облегает. Полы ниже
    таза: куртка до середины бедра меняет силуэт сильнее, чем любая
    проработка ткани.
    """
    joints = [
        ((0.0, 0.0, 1.02), 0.165, 0.115),
        ((0.0, -0.01, 1.2), 0.17, 0.12),
        ((0.0, -0.03, CHEST_Z), 0.2, 0.135),
        ((0.0, -0.05, 1.52), 0.15, 0.115),

        ((-0.2, -0.04, 1.47), 0.085, 0.08),
        ((-0.235, 0.0, 1.18), 0.07, 0.068),
        ((-0.25, 0.02, 0.98), 0.055, 0.055),

        ((0.2, -0.04, 1.48), 0.085, 0.08),
        ((0.23, -0.02, 1.19), 0.07, 0.068),
        ((0.245, 0.0, 0.99), 0.055, 0.055),
    ]
    bones = [(0, 1), (1, 2), (2, 3), (2, 4), (4, 5), (5, 6), (2, 7), (7, 8), (8, 9)]

    jacket = skinned("jacket", joints, bones)

    parts = [jacket]

    # Полы куртки: усечённый конус, расширяющийся книзу.
    bpy.ops.mesh.primitive_cone_add(
        radius1=0.175, radius2=0.215, depth=0.34, location=(0.0, -0.005, 0.87), vertices=20
    )
    skirt = bpy.context.active_object
    skirt.name = "skirt"
    skirt.scale = (1.0, 0.72, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.object.select_all(action="DESELECT")
    parts.append(skirt)

    # Воротник-стойка.
    parts.append(tube("collar", 0.098, 0.09, (0.0, -0.05, 1.61), verts=18))

    # Капюшон, лежащий на спине: складка, а не полусфера.
    hood = sphere("hood", 0.12, (0.0, 0.055, 1.46), (1.0, 0.72, 1.15),
                  (math.radians(-14), 0, 0))
    parts.append(hood)

    # Планка застёжки по центру груди.
    parts.append(box("placket", (0.045, 0.03, 0.5), (0.0, -0.14, 1.24), bevel=0.008))

    result = join(parts, "jacket")
    smooth(result, 40)
    return result


# --- Этап 4: штаны и ботинки -------------------------------------------

def build_legs_gear():
    """Штаны, ботинки, наколенники.

    Ботинок — не цилиндр: подошва, союзка и голенище имеют разную
    ширину, и именно перепад делает его обувью, а не трубой.
    """
    parts = []

    for side in (-1, 1):
        x = side * 0.095

        # Штанина: оболочка поверх ноги.
        joints = [
            ((x, 0.0, 0.95), 0.105, 0.1),
            ((x * 1.05, 0.01, KNEE_Z + 0.06), 0.085, 0.085),
            ((x * 1.15, 0.0, 0.24), 0.075, 0.078),
        ]
        parts.append(skinned("trouser", joints, [(0, 1), (1, 2)]))

        # Наколенник — накладка, ловящая свет отдельно от штанины.
        parts.append(box("knee_pad", (0.09, 0.055, 0.09),
                         (x * 1.05, -0.055, KNEE_Z + 0.02),
                         (math.radians(4), 0, 0), bevel=0.012))

        # Ботинок: голенище, союзка, подошва.
        parts.append(tube("boot_shaft", 0.072, 0.2, (x * 1.15, 0.0, 0.16), verts=16))
        parts.append(box("boot_vamp", (0.098, 0.16, 0.075),
                         (x * 1.15, -0.055, 0.055), bevel=0.02))
        parts.append(box("boot_sole", (0.108, 0.235, 0.028),
                         (x * 1.15, -0.045, 0.016), bevel=0.008))

    result = join(parts, "legs_gear")
    smooth(result, 40)
    return result


# --- Этап 5: снаряжение ------------------------------------------------

def build_gear():
    """Ремень, подсумки, лямки рюкзака, фонарь на плече.

    Мелочь, по которой человек читается снаряжённым. Ровно она
    отличает сталкера от прохожего, и её должно быть видно
    в силуэте — поэтому всё торчит наружу, а не прилегает.
    """
    parts = []

    # Ремень и пряжка.
    parts.append(tube("belt", 0.178, 0.05, (0.0, -0.005, 0.99), verts=22))
    parts.append(box("buckle", (0.055, 0.03, 0.045), (0.0, -0.155, 0.99), bevel=0.006))

    # Подсумки на ремне, разного размера и не симметрично.
    parts.append(box("pouch_l", (0.085, 0.06, 0.11), (-0.14, -0.075, 0.95),
                     (0, 0, math.radians(-12)), bevel=0.012))
    parts.append(box("pouch_r", (0.07, 0.055, 0.085), (0.155, -0.045, 0.965),
                     (0, 0, math.radians(9)), bevel=0.012))

    # Лямки рюкзака через плечи.
    for side in (-1, 1):
        parts.append(box("strap", (0.045, 0.028, 0.42),
                         (side * 0.11, -0.115, 1.36),
                         (math.radians(6), 0, side * math.radians(4)), bevel=0.008))

    # Рюкзак за спиной.
    parts.append(box("pack", (0.27, 0.15, 0.34), (0.0, 0.135, 1.3),
                     (math.radians(-3), 0, 0), bevel=0.03))
    parts.append(box("pack_flap", (0.25, 0.13, 0.09), (0.0, 0.135, 1.44),
                     (math.radians(-3), 0, 0), bevel=0.015))

    # Фонарь на левом плече — источник, который игрок увидит на записи.
    parts.append(tube("lamp_body", 0.032, 0.09, (-0.2, -0.075, 1.53),
                      (math.radians(90), 0, 0), verts=14))

    result = join(parts, "gear")
    smooth(result, 35)
    return result


# --- Сборка ------------------------------------------------------------

def export(objects, name):
    os.makedirs(OUT_DIR, exist_ok=True)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]

    # Объединяем перед поворотом. Поворот группы разворачивает каждый
    # объект вокруг его собственного центра, и части фигуры разъезжаются:
    # голова уходит в одну сторону, ботинки в другую.
    # Материалы при объединении сохраняются отдельными слотами.
    if len(objects) > 1:
        bpy.ops.object.join()
    merged = bpy.context.active_object

    # Blender считает вверхом Z, glTF и Godot — Y. Поворачиваем сами
    # и отключаем конверсию экспортёра.
    merged.rotation_euler = (-math.pi / 2, 0, 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)

    path = os.path.join(OUT_DIR, "%s.glb" % name)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=False,
    )

    print("сохранено: %s — слоёв %d, вершин %d"
          % (path, len(merged.data.materials), len(merged.data.vertices)))


def make_stalker():
    clear_scene()

    # Тона подобраны под палитру дома: он тёмный, и персонаж светлее
    # стен выглядит вырезанным из другой игры. Кожа заметно темнее
    # реальной по той же причине — в кадре она единственное пятно
    # без ткани, и на светлой коже глаз залипает вместо доски.
    skin_mat = material("skin", (0.34, 0.26, 0.22), 0.75)
    cloth_mat = material("cloth", (0.14, 0.15, 0.13), 0.9)
    trouser_mat = material("trousers", (0.11, 0.11, 0.1), 0.92)
    gear_mat = material("gear", (0.08, 0.075, 0.07), 0.6, 0.2)

    body = build_body()
    assign(body, skin_mat)

    head = build_head()
    assign(head, skin_mat)

    jacket = build_jacket()
    assign(jacket, cloth_mat)

    legs = build_legs_gear()
    assign(legs, trouser_mat)

    gear = build_gear()
    assign(gear, gear_mat)

    export([body, head, jacket, legs, gear], "stalker")


def main():
    make_stalker()
    print("готово: сталкер в %s" % OUT_DIR)


if __name__ == "__main__":
    main()
