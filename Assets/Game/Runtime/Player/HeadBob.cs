using UnityEngine;

namespace Game.Player
{
    /// <summary>
    /// Покачивание камеры при ходьбе — самая дешёвая вещь, отличающая
    /// «камера летает» от «человек идёт».
    ///
    /// Обычный класс, а не компонент: это чистая функция времени, и её
    /// удобно проверять без запуска сцены.
    /// </summary>
    public sealed class HeadBob
    {
        /// <summary>Насколько быстро качание затухает после остановки.</summary>
        private const float SettleSpeed = 8f;

        /// <summary>Крен в стороны. Добавляет шагу веса, но заметным быть не должен.</summary>
        private const float RollAmount = 0.006f;

        private readonly float _amount;
        private readonly float _speed;

        private float _time;
        private float _lastPhase;

        public HeadBob(float amount, float speed)
        {
            _amount = amount;
            _speed = speed;
        }

        /// <summary>Смещение головы по вертикали относительно нейтрали.</summary>
        public float VerticalOffset { get; private set; }

        /// <summary>Крен головы вокруг оси взгляда, в радианах.</summary>
        public float Roll { get; private set; }

        /// <summary>
        /// Продвинуть качание на кадр. Возвращает true в тот единственный
        /// кадр, когда нога касается пола.
        ///
        /// Момент шага берётся из фазы качания, а не из таймера: только так
        /// звук совпадает с тем, что видит глаз.
        /// </summary>
        public bool Advance(float deltaTime, bool isMoving)
        {
            if (!isMoving)
            {
                _time = 0f;
                _lastPhase = 0f;

                // Затухание экспоненциальное: линейное давало заметный излом
                // в момент остановки.
                var settle = 1f - Mathf.Exp(-SettleSpeed * deltaTime);
                VerticalOffset = Mathf.Lerp(VerticalOffset, 0f, settle);
                Roll = Mathf.Lerp(Roll, 0f, settle);
                return false;
            }

            _time += deltaTime * _speed;

            var phase = Mathf.Sin(_time);
            VerticalOffset = phase * _amount;
            Roll = Mathf.Cos(_time * 0.5f) * RollAmount;

            // Шаг — на переходе качания вниз через нейтраль.
            var isStep = _lastPhase > 0f && phase <= 0f;
            _lastPhase = phase;
            return isStep;
        }
    }
}
