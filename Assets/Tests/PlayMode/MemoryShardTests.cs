using System.Collections;
using Game.Progression;
using Game.World;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestTools;

namespace Game.Tests
{
    public sealed class MemoryShardTests
    {
        private const string ShardId = "night_01";

        private GameObject _sessionObject;
        private GameObject _shardObject;

        [SetUp]
        public void SetUp()
        {
            _sessionObject = new GameObject("GameSession");
            _sessionObject.AddComponent<GameSession>();
        }

        [TearDown]
        public void TearDown()
        {
            if (_shardObject != null)
            {
                Object.DestroyImmediate(_shardObject);
            }

            Object.DestroyImmediate(_sessionObject);
        }

        private MemoryShard CreateShard(string id)
        {
            _shardObject = new GameObject("Shard");
            _shardObject.SetActive(false);

            var shard = _shardObject.AddComponent<MemoryShard>();
            PrivateField.Set(shard, "_id", id);
            _shardObject.SetActive(true);
            return shard;
        }

        [UnityTest]
        public IEnumerator TryInteract_FirstTime_CollectsShard()
        {
            var shard = CreateShard(ShardId);
            yield return null;

            Assert.IsTrue(shard.TryInteract());
            Assert.IsTrue(GameSession.Current.State.HasShard(ShardId));
            Assert.AreEqual(1, GameSession.Current.State.ShardCount);
        }

        /// <summary>
        /// Осколок должен исчезать сразу, а не в конце кадра: иначе мишень
        /// ещё успела бы попасть под луч взгляда и подсказка мигнула бы.
        /// </summary>
        [UnityTest]
        public IEnumerator TryInteract_DeactivatesImmediately()
        {
            var shard = CreateShard(ShardId);
            yield return null;

            shard.TryInteract();

            Assert.IsFalse(shard.gameObject.activeSelf);
        }

        /// <summary>
        /// Второй такой же осколок уже собран и в руки не даётся: так подбор
        /// не засчитывается дважды при перезаходе в комнату.
        /// </summary>
        [UnityTest]
        public IEnumerator TryInteract_WhenAlreadyCollected_IsRefused()
        {
            GameSession.Current.State.TryCollectShard(ShardId);

            var shard = CreateShard(ShardId);
            yield return null;

            Assert.IsFalse(shard.TryInteract());
            Assert.AreEqual(1, GameSession.Current.State.ShardCount);
        }

        /// <summary>Уже собранный осколок не появляется в комнате заново.</summary>
        [UnityTest]
        public IEnumerator Awake_WhenAlreadyCollected_RemovesItself()
        {
            GameSession.Current.State.TryCollectShard(ShardId);

            CreateShard(ShardId);
            yield return null;

            Assert.IsTrue(_shardObject == null, "Собранный осколок должен был удалить себя");
        }

        [UnityTest]
        public IEnumerator Awake_WithFreshId_KeepsShardInPlace()
        {
            CreateShard(ShardId);
            yield return null;

            Assert.IsTrue(_shardObject != null);
        }

        [UnityTest]
        public IEnumerator Awake_WithoutId_WarnsAndSurvives()
        {
            LogAssert.Expect(LogType.Warning, "Осколок без идентификатора — он не сохранится");

            CreateShard("");
            yield return null;

            Assert.IsTrue(_shardObject != null);
        }
    }
}
