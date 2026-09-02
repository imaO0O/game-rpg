using Game.Progression;
using NUnit.Framework;
using UnityEngine;

namespace Game.Tests
{
    public sealed class GameStateTests
    {
        private GameState _state;

        [SetUp]
        public void SetUp()
        {
            _state = new GameState();
        }

        [Test]
        public void TryCollectShard_FirstTime_Succeeds()
        {
            Assert.IsTrue(_state.TryCollectShard("night_01"));
            Assert.IsTrue(_state.HasShard("night_01"));
            Assert.AreEqual(1, _state.ShardCount);
        }

        /// <summary>
        /// Повторный подбор не засчитывается: иначе счётчик рос бы при каждом
        /// перезаходе в комнату.
        /// </summary>
        [Test]
        public void TryCollectShard_Twice_CountsOnce()
        {
            _state.TryCollectShard("night_01");

            Assert.IsFalse(_state.TryCollectShard("night_01"));
            Assert.AreEqual(1, _state.ShardCount);
        }

        [Test]
        public void TryCollectShard_FirstTime_RaisesEventOnce()
        {
            var raised = 0;
            var reportedTotal = 0;
            _state.ShardCollected += (_, total) =>
            {
                raised++;
                reportedTotal = total;
            };

            _state.TryCollectShard("night_01");
            _state.TryCollectShard("night_01");

            Assert.AreEqual(1, raised);
            Assert.AreEqual(1, reportedTotal);
        }

        [Test]
        public void TryCollectShard_WithEmptyId_IsRefused()
        {
            Assert.IsFalse(_state.TryCollectShard(""));
            Assert.AreEqual(0, _state.ShardCount);
        }

        [Test]
        public void TrySetFlag_Twice_SucceedsOnlyOnce()
        {
            Assert.IsTrue(_state.TrySetFlag("scare_pinkie"));
            Assert.IsFalse(_state.TrySetFlag("scare_pinkie"));
            Assert.IsTrue(_state.HasFlag("scare_pinkie"));
        }

        [Test]
        public void SetCheckpoint_StoresPlaceAndNotifies()
        {
            var reported = "";
            _state.CheckpointReached += id => reported = id;

            _state.SetCheckpoint("kitchen", "House", new Vector3(1f, 2f, 3f));

            Assert.AreEqual("kitchen", _state.CheckpointId);
            Assert.AreEqual("House", _state.CheckpointScene);
            Assert.AreEqual(new Vector3(1f, 2f, 3f), _state.CheckpointPosition);
            Assert.AreEqual("kitchen", reported);
            Assert.IsTrue(_state.HasCheckpoint);
        }

        [Test]
        public void Reset_ClearsEverything()
        {
            _state.TryCollectShard("night_01");
            _state.TrySetFlag("scare_pinkie");
            _state.SetCheckpoint("kitchen", "House", Vector3.one);
            _state.AdvancePlaytime(12f);

            _state.Reset();

            Assert.AreEqual(0, _state.ShardCount);
            Assert.IsFalse(_state.HasFlag("scare_pinkie"));
            Assert.IsFalse(_state.HasCheckpoint);
            Assert.AreEqual(0f, _state.Playtime, 0.001f);
        }

        [Test]
        public void LoadFrom_AfterToData_RestoresEverything()
        {
            _state.TryCollectShard("night_01");
            _state.TryCollectShard("night_04");
            _state.TrySetFlag("scare_mirror");
            _state.SetCheckpoint("kitchen", "House", new Vector3(4f, 0f, -2f));
            _state.AdvancePlaytime(90f);

            var restored = new GameState();
            restored.LoadFrom(_state.ToData());

            Assert.AreEqual(2, restored.ShardCount);
            Assert.IsTrue(restored.HasShard("night_01"));
            Assert.IsTrue(restored.HasShard("night_04"));
            Assert.IsTrue(restored.HasFlag("scare_mirror"));
            Assert.AreEqual("kitchen", restored.CheckpointId);
            Assert.AreEqual(new Vector3(4f, 0f, -2f), restored.CheckpointPosition);
            Assert.AreEqual(90f, restored.Playtime, 0.001f);
        }

        /// <summary>
        /// Загрузка заменяет состояние целиком. Подмешивать сохранение
        /// к текущему прогрессу — верный способ получить осколок,
        /// собранный дважды.
        /// </summary>
        [Test]
        public void LoadFrom_ReplacesCurrentProgress()
        {
            _state.TryCollectShard("night_01");
            var snapshot = _state.ToData();

            _state.TryCollectShard("night_02");
            _state.LoadFrom(snapshot);

            Assert.AreEqual(1, _state.ShardCount);
            Assert.IsFalse(_state.HasShard("night_02"));
        }

        [Test]
        public void AdvancePlaytime_Accumulates()
        {
            _state.AdvancePlaytime(1.5f);
            _state.AdvancePlaytime(2.5f);

            Assert.AreEqual(4f, _state.Playtime, 0.001f);
        }
    }
}
