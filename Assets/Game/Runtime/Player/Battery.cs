using UnityEngine;

namespace Game.Player
{
    /// <summary>
    /// Заряд фонаря — единственный ресурс в игре.
    ///
    /// Отдельный класс без Unity-жизненного цикла: правило простое,
    /// проверяется без запуска сцены, и не хочется тянуть весь фонарь
    /// в тест ради одной формулы.
    /// </summary>
    public sealed class Battery
    {
        private readonly float _fullChargeSeconds;

        public Battery(float fullChargeSeconds)
        {
            // Ноль или отрицательное время означало бы деление на ноль
            // и мгновенно севший фонарь — лучше упасть на настройке.
            Debug.Assert(fullChargeSeconds > 0f, "Время работы фонаря должно быть больше нуля");
            _fullChargeSeconds = fullChargeSeconds;
        }

        /// <summary>Остаток заряда, от 0 до 1.</summary>
        public float Charge { get; private set; } = 1f;

        public bool IsEmpty => Charge <= 0f;

        /// <summary>
        /// Потратить заряд за кадр. Вызывается только пока фонарь горит:
        /// выключенный свет не тратит батарею.
        /// </summary>
        public void Drain(float deltaTime)
        {
            Charge = Mathf.Max(0f, Charge - deltaTime / _fullChargeSeconds);
        }

        public void Recharge()
        {
            Charge = 1f;
        }
    }
}
