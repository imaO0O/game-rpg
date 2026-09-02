using System;

namespace Game.Narration
{
    /// <summary>
    /// Куда уходят разрядки скримеров.
    ///
    /// Ради этого класса всё и затевалось. В предыдущей версии разрядка
    /// уходила в печать в консоль — то есть для игрока шутки не существовало,
    /// и от скримера оставалась только первая, страшная половина.
    ///
    /// Обычный класс без Unity-жизненного цикла: канал живёт в сессии,
    /// подписчик — интерфейс. Кто именно показывает субтитр, скримеру знать
    /// незачем.
    /// </summary>
    public sealed class PunchlineChannel
    {
        /// <summary>Прозвучала разрядка. На это подписан субтитр.</summary>
        public event Action<Punchline> Delivered;

        /// <summary>Последняя прозвучавшая. Нужна интерфейсу при пересоздании.</summary>
        public Punchline Last { get; private set; }

        public int DeliveredCount { get; private set; }

        /// <summary>
        /// Пустая разрядка молча игнорируется: ронять игру из-за незаполненной
        /// реплики незачем, а о самой пустоте предупреждает скример при старте
        /// сцены — там это видно раньше и понятнее.
        /// </summary>
        public void Deliver(Punchline punchline)
        {
            if (punchline.IsEmpty)
            {
                return;
            }

            Last = punchline;
            DeliveredCount++;
            Delivered?.Invoke(punchline);
        }
    }
}
