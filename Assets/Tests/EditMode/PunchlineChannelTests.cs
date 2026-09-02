using Game.Narration;
using NUnit.Framework;

namespace Game.Tests
{
    public sealed class PunchlineChannelTests
    {
        private static Punchline Line(string text) =>
            new() { Speaker = "Пинки", Line = text };

        [Test]
        public void Deliver_RaisesEventWithSameLine()
        {
            var channel = new PunchlineChannel();
            var received = new Punchline();
            channel.Delivered += punchline => received = punchline;

            channel.Deliver(Line("ой. я думала, ты знала, что я тут."));

            Assert.AreEqual("Пинки", received.Speaker);
            Assert.AreEqual("ой. я думала, ты знала, что я тут.", received.Line);
        }

        [Test]
        public void Deliver_RemembersLastAndCounts()
        {
            var channel = new PunchlineChannel();

            channel.Deliver(Line("первая"));
            channel.Deliver(Line("вторая"));

            Assert.AreEqual("вторая", channel.Last.Line);
            Assert.AreEqual(2, channel.DeliveredCount);
        }

        /// <summary>
        /// Пустая реплика молча игнорируется: ронять игру из-за незаполненного
        /// текста незачем, а о самой пустоте предупреждает скример при старте
        /// сцены — там это видно раньше и понятнее.
        /// </summary>
        [Test]
        public void Deliver_WithEmptyLine_IsIgnored()
        {
            var channel = new PunchlineChannel();
            var raised = 0;
            channel.Delivered += _ => raised++;

            channel.Deliver(new Punchline());
            channel.Deliver(new Punchline { Speaker = "Пинки", Line = "   " });

            Assert.AreEqual(0, raised);
            Assert.AreEqual(0, channel.DeliveredCount);
        }

        [Test]
        public void ToString_WithSpeaker_ReadsAsDialogue()
        {
            Assert.AreEqual("Пинки: забирай.",
                new Punchline { Speaker = "Пинки", Line = "забирай." }.ToString());
        }

        [Test]
        public void ToString_WithoutSpeaker_IsBareLine()
        {
            Assert.AreEqual("SORRY. YOUR CALL.",
                new Punchline { Line = "SORRY. YOUR CALL." }.ToString());
        }

        [Test]
        public void IsEmpty_ForBlankLine_IsTrue()
        {
            Assert.IsTrue(new Punchline().IsEmpty);
            Assert.IsTrue(new Punchline { Line = "  " }.IsEmpty);
            Assert.IsFalse(new Punchline { Line = "есть" }.IsEmpty);
        }
    }
}
