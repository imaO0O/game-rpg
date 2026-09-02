using Game.Player;
using NUnit.Framework;

namespace Game.Tests
{
    public sealed class BatteryTests
    {
        private const float FullChargeSeconds = 240f;
        private const float Tolerance = 0.001f;

        [Test]
        public void NewBattery_IsFullyCharged()
        {
            var battery = new Battery(FullChargeSeconds);

            Assert.AreEqual(1f, battery.Charge, Tolerance);
            Assert.IsFalse(battery.IsEmpty);
        }

        [Test]
        public void Drain_ForHalfTheDuration_LeavesHalfCharge()
        {
            var battery = new Battery(FullChargeSeconds);

            battery.Drain(FullChargeSeconds / 2f);

            Assert.AreEqual(0.5f, battery.Charge, Tolerance);
        }

        [Test]
        public void Drain_ForFullDuration_EmptiesBattery()
        {
            var battery = new Battery(FullChargeSeconds);

            battery.Drain(FullChargeSeconds);

            Assert.IsTrue(battery.IsEmpty);
        }

        /// <summary>
        /// Отрицательный заряд сломал бы формулу предупреждения: она делит
        /// остаток на порог и ждёт значение от нуля до единицы.
        /// </summary>
        [Test]
        public void Drain_PastEmpty_ClampsAtZero()
        {
            var battery = new Battery(FullChargeSeconds);

            battery.Drain(FullChargeSeconds * 2f);

            Assert.AreEqual(0f, battery.Charge, Tolerance);
        }

        [Test]
        public void Recharge_AfterDraining_RestoresFullCharge()
        {
            var battery = new Battery(FullChargeSeconds);
            battery.Drain(FullChargeSeconds * 0.9f);

            battery.Recharge();

            Assert.AreEqual(1f, battery.Charge, Tolerance);
            Assert.IsFalse(battery.IsEmpty);
        }

        /// <summary>
        /// Накопление по кадрам должно давать тот же результат, что один
        /// длинный шаг: иначе разряд зависел бы от частоты кадров.
        /// </summary>
        [Test]
        public void Drain_InSmallSteps_MatchesSingleStep()
        {
            var stepped = new Battery(FullChargeSeconds);
            var once = new Battery(FullChargeSeconds);
            const float frame = 1f / 60f;
            const int frames = 600;

            for (var i = 0; i < frames; i++)
            {
                stepped.Drain(frame);
            }

            once.Drain(frame * frames);

            Assert.AreEqual(once.Charge, stepped.Charge, Tolerance);
        }
    }
}
