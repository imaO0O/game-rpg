using System.Collections;
using Game.Narration;
using Game.Progression;
using Game.Scares;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestTools;

namespace Game.Tests
{
    public sealed class SpiderScareTests
    {
        private static readonly Vector3 RestPosition = new(0f, 1.7f, 0.4f);

        private GameObject _sessionObject;
        private GameObject _scareObject;
        private Transform _anchor;

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

            Object.DestroyImmediate(_sessionObject);
        }

        private SpiderScare CreateScare()
        {
            _scareObject = new GameObject("SpiderScare");
            _scareObject.SetActive(false);

            var anchor = new GameObject("Anchor");
            anchor.transform.SetParent(_scareObject.transform, false);
            anchor.transform.localPosition = RestPosition;
            _anchor = anchor.transform;

            var scare = _scareObject.AddComponent<SpiderScare>();
            PrivateField.Set(scare, "_id", "spider");
            PrivateField.Set(scare, "_strikeSeconds", 0.05f);
            PrivateField.Set(scare, "_anchor", _anchor);
            PrivateField.Set(scare, "_dropSeconds", 0.05f);
            PrivateField.Set(scare, "_punchline", new Punchline
            {
                Speaker = "Пинки",
                Line = "спокойно, он игрушечный. в отличие от меня.",
            });

            _scareObject.SetActive(true);
            return scare;
        }

        /// <summary>До удара его в комнате нет — иначе всё падение зря.</summary>
        [UnityTest]
        public IEnumerator Awake_HidesAnchor()
        {
            CreateScare();
            yield return null;

            Assert.IsFalse(_anchor.gameObject.activeSelf);
        }

        [UnityTest]
        public IEnumerator Fire_DropsAnchorToItsMarkedPlace()
        {
            var scare = CreateScare();
            yield return null;

            scare.Fire();
            yield return new WaitForSeconds(0.2f);

            Assert.IsTrue(_anchor.gameObject.activeSelf);
            Assert.AreEqual(RestPosition.y, _anchor.localPosition.y, 0.01f,
                "Должен остановиться ровно там, где размечено");
        }

        /// <summary>
        /// Реплика звучит только после того, как фигурка перестала болтаться:
        /// шутка поверх ещё качающегося силуэта прозвучала бы в пустоту.
        /// </summary>
        [UnityTest]
        public IEnumerator Punchline_WaitsForSwingToSettle()
        {
            var scare = CreateScare();
            yield return null;

            var swingAtDelivery = -1f;
            GameSession.Current.Punchlines.Delivered +=
                _ => swingAtDelivery = scare.SwingEnvelope();

            scare.Fire();
            yield return new WaitUntil(() => !scare.IsRunning);

            Assert.GreaterOrEqual(swingAtDelivery, 0f, "Разрядка не прозвучала");
            Assert.LessOrEqual(swingAtDelivery, 3f, "Прозвучала, пока ещё качалось");
        }

        /// <summary>
        /// В отличие от Пинки, паучок никуда не девается. В этом половина
        /// шутки: мимо него потом можно ходить.
        /// </summary>
        [UnityTest]
        public IEnumerator Resolve_LeavesToyHanging()
        {
            var scare = CreateScare();
            yield return null;

            scare.Fire();
            yield return new WaitUntil(() => !scare.IsRunning);

            Assert.IsTrue(_anchor != null && _anchor.gameObject.activeSelf);
        }

        [UnityTest]
        public IEnumerator Swing_DecaysOverTime()
        {
            var scare = CreateScare();
            yield return null;

            scare.Fire();
            yield return new WaitForSeconds(0.2f);
            var early = scare.SwingEnvelope();

            yield return new WaitForSeconds(0.6f);
            var later = scare.SwingEnvelope();

            Assert.Greater(early, later, "Раскачка обязана затухать");
        }
    }
}
