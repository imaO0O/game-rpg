using UnityEngine;

namespace Game
{
    /// <summary>
    /// Слои проекта. Индексы заданы в Project Settings и здесь только
    /// названы, чтобы в коде не оставалось голых чисел.
    /// </summary>
    public static class GameLayers
    {
        /// <summary>
        /// Цели луча взгляда. Обычная геометрия на этом слое не висит:
        /// иначе предмет на столе было бы не взять из-за самого стола.
        /// </summary>
        public const int Interactable = 6;

        /// <summary>
        /// Тело игрока. Основная камера этот слой не рисует — иначе
        /// собственное тело закрывало бы весь обзор изнутри головы.
        /// Камеры наблюдения рисуют, в этом весь смысл.
        /// </summary>
        public const int CameraOnly = 7;

        public static readonly LayerMask InteractableMask = 1 << Interactable;
        public static readonly LayerMask CameraOnlyMask = 1 << CameraOnly;
    }
}
