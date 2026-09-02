using System.Collections;
using Game.Narration;
using Game.Progression;
using Game.Scares;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestTools;

namespace Game.Tests
{
    /// <summary>
    /// Общий контракт скримера. Здесь проверяется главное правило жанра:
    /// удар всегда доходит до разрядки, и разрядка доходит до игрока.
    /// </summary>
    public sealed class ScareTests
    {
        private const string ScareId = "pinkie";
        private const float StrikeSeconds = 0.05f;
        private const string PunchlineText = "ой. я думала, ты знала, что я тут.";

        private GameObject _sessionObject;
        private GameObject _scareObject;
        private GameObject _playerObject;

        /// <summary>Заглушка: считает такты и запоминает их порядок.</summary>
        private sealed class StubScare : Scare
        {
            public int StrikeCount { get; private set; }

            public int ResolveCount { get; private set; }

            protected override void Strike()
            {
                StrikeCount++;
            }

            protected override IEnumerator Resolve()
            {
                ResolveCount++;
                yield break;
            }
        }

        [SetUp]
        public void SetUp()
        {
            _sessionObject = new GameObject("GameSession");
            _sessionObject.AddComponent<GameSession>();
        }

        [TearDown]
        public void TearDown()
        {
            if (_scareObject != null)
            {
                Object.DestroyImmediate(_scareObject);
            }

            if (_playerObject != null)
            {
                Object.DestroyImmediate(_playerObject);
            }

            Object.DestroyImmediate(_sessionObject);
        }

        private StubScare CreateScare(string id = ScareId, string punchline = PunchlineText)
        {
            _scareObject = new GameObject("Scare");
            _scareObject.SetActive(false);

            var scare = _scareObject.AddComponent<StubScare>();
            PrivateField.Set(scare, "_id", id);
            PrivateField.Set(scare, "_strikeSeconds", StrikeSeconds);
            PrivateField.Set(scare, "_punchline",
                new Punchline { Speaker = "Пинки", Line = punchline });

            _scareObject.SetActive(true);
            return scare;
        }

        private static IEnumerator WaitForScare()
        {
            yield return new WaitForSeconds(StrikeSeconds * 4f);
        }

        [UnityTest]
        public IEnumerator Fire_StrikesThenResolves()
        {
            var scare = CreateScare();

            Assert.IsTrue(scare.Fire());
            Assert.AreEqual(1, scare.StrikeCount, "Удар должен быть мгновенным");
            Assert.AreEqual(0, scare.ResolveCount, "Разрядка не должна опережать удар");

            yield return WaitForScare();

            Assert.AreEqual(1, scare.ResolveCount);
            Assert.IsFalse(scare.IsRunning);
        }

        /// <summary>
        /// Разрядка обязана дойти до игрока. В предыдущей версии она уходила
        /// в консоль, и от скримера оставалась только страшная половина.
        /// </summary>
        [UnityTest]
        public IEnumerator Fire_DeliversPunchlineToChannel()
        {
            var scare = CreateScare();
            var received = new Punchline();
            GameSession.Current.Punchlines.Delivered += punchline => received = punchline;

            scare.Fire();
            yield return WaitForScare();

            Assert.AreEqual(PunchlineText, received.Line);
            Assert.AreEqual(1, GameSession.Current.Punchlines.DeliveredCount);
        }

        /// <summary>
        /// Реплика звучит после того, как всё улеглось: разрядка может длиться,
        /// и шутка поверх ещё идущего испуга не сработает.
        /// </summary>
        [UnityTest]
        public IEnumerator Punchline_ArrivesAfterResolveFinished()
        {
            var scare = CreateScare();
            var resolveCountAtDelivery = -1;
            GameSession.Current.Punchlines.Delivered +=
                _ => resolveCountAtDelivery = scare.ResolveCount;

            scare.Fire();
            yield return WaitForScare();

            Assert.AreEqual(1, resolveCountAtDelivery);
        }

        [UnityTest]
        public IEnumerator Fire_Twice_RunsOnce()
        {
            var scare = CreateScare();

            Assert.IsTrue(scare.Fire());
            Assert.IsFalse(scare.Fire(), "Повторный запуск должен игнорироваться");

            yield return WaitForScare();

            Assert.AreEqual(1, scare.StrikeCount);
            Assert.IsFalse(scare.Fire(), "Сработавший скример больше не стреляет");
        }

        [UnityTest]
        public IEnumerator Fire_RaisesFlagInGameState()
        {
            var scare = CreateScare();

            scare.Fire();
            yield return WaitForScare();

            Assert.IsTrue(GameSession.Current.State.HasFlag($"scare_{ScareId}"));
        }

        /// <summary>Скример, сработавший в прошлый раз, при возврате в комнату молчит.</summary>
        [UnityTest]
        public IEnumerator Awake_WhenFlagAlreadySet_IsNotArmed()
        {
            GameSession.Current.State.TrySetFlag($"scare_{ScareId}");

            var scare = CreateScare();
            yield return null;

            Assert.IsFalse(scare.IsArmed);
            Assert.IsFalse(scare.Fire());
        }

        /// <summary>
        /// Взвести обратно нужно там, где событие повторяется несколько раз
        /// подряд, — убегающий осколок должен убежать трижды.
        /// </summary>
        [UnityTest]
        public IEnumerator Rearm_AllowsFiringAgain()
        {
            var scare = CreateScare();
            scare.Fire();
            yield return WaitForScare();

            scare.Rearm();

            Assert.IsTrue(scare.Fire());
            yield return WaitForScare();
            Assert.AreEqual(2, scare.StrikeCount);
        }

        [UnityTest]
        public IEnumerator Awake_WithoutPunchline_Warns()
        {
            LogAssert.Expect(LogType.Warning, new System.Text.RegularExpressions.Regex(
                "без разрядки"));

            CreateScare(punchline: "");
            yield return null;
        }

        /// <summary>Скример без идентификатора сработает заново после загрузки.</summary>
        [UnityTest]
        public IEnumerator Awake_WithoutId_Warns()
        {
            LogAssert.Expect(LogType.Warning, new System.Text.RegularExpressions.Regex(
                "без идентификатора"));

            CreateScare(id: "");
            yield return null;
        }

        [UnityTest]
        public IEnumerator OnTriggerEnter_WithPlayer_Fires()
        {
            var scare = CreateScare();
            var trigger = _scareObject.AddComponent<BoxCollider>();
            trigger.size = new Vector3(3f, 2.4f, 2f);
            trigger.isTrigger = true;

            // Событиям триггера нужно тело хотя бы с одной стороны.
            _playerObject = new GameObject("Player") { tag = "Player" };
            _playerObject.transform.position = new Vector3(0f, 0f, 20f);
            _playerObject.AddComponent<SphereCollider>().radius = 0.3f;
            _playerObject.AddComponent<Rigidbody>().isKinematic = true;

            yield return new WaitForFixedUpdate();
            Assert.AreEqual(0, scare.StrikeCount, "Издалека срабатывать не должен");

            _playerObject.transform.position = Vector3.zero;
            yield return new WaitForFixedUpdate();
            yield return null;

            Assert.AreEqual(1, scare.StrikeCount);
        }
    }
}
