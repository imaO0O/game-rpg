using Game.Player;
using NUnit.Framework;
using UnityEngine;

namespace Game.Tests
{
    public sealed class HeadBobTests
    {
        private const float Amount = 0.035f;
        private const float Speed = 9f;
        private const float Frame = 1f / 240f;

        /// <summary>Полный цикл качания — два шага синуса, то есть один шаг ноги.</summary>
        private static float CycleSeconds => 2f * Mathf.PI / Speed;

        private static int CountSteps(HeadBob bob, float seconds, bool isMoving)
        {
            var steps = 0;
            for (var elapsed = 0f; elapsed < seconds; elapsed += Frame)
            {
                if (bob.Advance(Frame, isMoving))
                {
                    steps++;
                }
            }

            return steps;
        }

        [Test]
        public void Advance_WhileStanding_ReportsNoStep()
        {
            var bob = new HeadBob(Amount, Speed);

            Assert.AreEqual(0, CountSteps(bob, CycleSeconds * 3f, isMoving: false));
        }

        /// <summary>
        /// Ровно один шаг за цикл. Два означали бы, что звук идёт и на подъёме,
        /// и на спуске, — походка звучала бы вдвое чаще, чем выглядит.
        /// </summary>
        [Test]
        public void Advance_OverOneCycle_ReportsExactlyOneStep()
        {
            var bob = new HeadBob(Amount, Speed);

            Assert.AreEqual(1, CountSteps(bob, CycleSeconds, isMoving: true));
        }

        [Test]
        public void Advance_OverFiveCycles_ReportsFiveSteps()
        {
            var bob = new HeadBob(Amount, Speed);

            Assert.AreEqual(5, CountSteps(bob, CycleSeconds * 5f, isMoving: true));
        }

        [Test]
        public void Advance_WhileWalking_KeepsOffsetWithinAmount()
        {
            var bob = new HeadBob(Amount, Speed);

            for (var elapsed = 0f; elapsed < CycleSeconds * 3f; elapsed += Frame)
            {
                bob.Advance(Frame, isMoving: true);
                Assert.LessOrEqual(Mathf.Abs(bob.VerticalOffset), Amount + 0.0001f);
            }
        }

        /// <summary>
        /// После остановки голова возвращается в нейтраль. Резкий скачок
        /// читался бы как рывок камеры.
        /// </summary>
        [Test]
        public void Advance_AfterStopping_SettlesTowardsNeutral()
        {
            var bob = new HeadBob(Amount, Speed);
            CountSteps(bob, CycleSeconds * 0.25f, isMoving: true);
            var offsetWhileWalking = Mathf.Abs(bob.VerticalOffset);

            CountSteps(bob, 1f, isMoving: false);

            Assert.Less(Mathf.Abs(bob.VerticalOffset), offsetWhileWalking);
            Assert.AreEqual(0f, bob.VerticalOffset, 0.001f);
            Assert.AreEqual(0f, bob.Roll, 0.001f);
        }

        /// <summary>
        /// Остановка сбрасывает фазу: иначе после паузы первый шаг звучал бы
        /// в случайный момент.
        /// </summary>
        [Test]
        public void Advance_AfterStopping_RestartsPhase()
        {
            var bob = new HeadBob(Amount, Speed);
            CountSteps(bob, CycleSeconds * 0.75f, isMoving: true);
            CountSteps(bob, 0.5f, isMoving: false);

            Assert.AreEqual(1, CountSteps(bob, CycleSeconds, isMoving: true));
        }
    }
}
