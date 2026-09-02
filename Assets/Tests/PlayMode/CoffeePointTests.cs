using System.Collections;
using System.IO;
using Game.Player;
using Game.Progression;
using Game.World;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestTools;

namespace Game.Tests
{
    /// <summary>
    /// Кофемашина делает три вещи разом, и все три проверяются здесь:
    /// ставит точку возврата, пишет файл и заряжает фонарь.
    ///
    /// Настоящее сохранение игрока на время теста отодвигается в сторону
    /// и возвращается обратно: путь берётся из Application, подменить его
    /// нечем, а затирать чужое прохождение недопустимо.
    /// </summary>
    public sealed class CoffeePointTests
    {
        private const string PointId = "kitchen";
        private const float BatterySeconds = 2f;

        private string _savePath;
        private string _backupPath;

        private GameObject _sessionObject;
        private GameObject _playerObject;
        private GameObject _pointObject;

        [SetUp]
        public void SetUp()
        {
            _savePath = Path.Combine(Application.persistentDataPath, GameSession.SaveFileName);
            _backupPath = _savePath + ".test-backup";
            if (File.Exists(_savePath))
            {
                File.Move(_savePath, _backupPath);
            }

            _sessionObject = new GameObject("GameSession");
            _sessionObject.AddComponent<GameSession>();
        }

        [TearDown]
        public void TearDown()
        {
            if (_pointObject != null)
            {
                Object.DestroyImmediate(_pointObject);
            }

            if (_playerObject != null)
            {
                Object.DestroyImmediate(_playerObject);
            }

            Object.DestroyImmediate(_sessionObject);

            if (File.Exists(_savePath))
            {
                File.Delete(_savePath);
            }

            if (File.Exists(_backupPath))
            {
                File.Move(_backupPath, _savePath);
            }
        }

        private CoffeePoint CreatePoint()
        {
            _pointObject = new GameObject("CoffeePoint");
            _pointObject.SetActive(false);
            _pointObject.transform.position = new Vector3(2f, 0f, -3f);

            var point = _pointObject.AddComponent<CoffeePoint>();
            PrivateField.Set(point, "_id", PointId);
            PrivateField.Set(point, "_drink", "раф");
            _pointObject.SetActive(true);
            return point;
        }

        /// <summary>Игрок с фонарём. Тег нужен, чтобы кофемашина его нашла.</summary>
        private Flashlight CreatePlayer()
        {
            _playerObject = new GameObject("Player") { tag = "Player" };
            _playerObject.SetActive(false);

            var lightObject = new GameObject("Flashlight");
            lightObject.transform.SetParent(_playerObject.transform, false);
            var light = lightObject.AddComponent<Light>();
            light.type = LightType.Spot;
            light.intensity = 1600f;

            var flashlight = lightObject.AddComponent<Flashlight>();
            // Настоящие 240 секунд в тесте не подождать.
            PrivateField.Set(flashlight, "_fullChargeSeconds", BatterySeconds);

            _playerObject.SetActive(true);
            return flashlight;
        }

        [UnityTest]
        public IEnumerator TryInteract_SetsCheckpointAtItsOwnPlace()
        {
            var point = CreatePoint();
            yield return null;

            Assert.IsTrue(point.TryInteract());

            var state = GameSession.Current.State;
            Assert.AreEqual(PointId, state.CheckpointId);
            Assert.AreEqual(new Vector3(2f, 0f, -3f), state.CheckpointPosition);
            Assert.IsTrue(state.HasCheckpoint);
        }

        [UnityTest]
        public IEnumerator TryInteract_WritesSaveFile()
        {
            var point = CreatePoint();
            GameSession.Current.State.TryCollectShard("night_02");
            yield return null;

            point.TryInteract();

            Assert.IsTrue(File.Exists(_savePath), "Кофемашина должна была записать сохранение");
            StringAssert.Contains("night_02", File.ReadAllText(_savePath));
        }

        [UnityTest]
        public IEnumerator TryInteract_RechargesFlashlight()
        {
            var flashlight = CreatePlayer();
            var point = CreatePoint();

            yield return new WaitForSeconds(BatterySeconds * 0.3f);
            Assert.Less(flashlight.Charge, 1f, "Фонарь должен был подсесть");

            point.TryInteract();

            Assert.AreEqual(1f, flashlight.Charge, 0.001f);
        }

        /// <summary>
        /// Пока идёт передышка, повторное нажатие ничего не делает: иначе
        /// точку покоя можно было бы прокликать и сбить всю паузу.
        /// </summary>
        [UnityTest]
        public IEnumerator TryInteract_WhileResting_IsRefused()
        {
            var point = CreatePoint();
            yield return null;

            Assert.IsTrue(point.TryInteract());
            Assert.IsTrue(point.IsResting);
            Assert.IsFalse(point.TryInteract());
        }

        [UnityTest]
        public IEnumerator Prompt_NamesTheDrink()
        {
            var point = CreatePoint();
            yield return null;

            Assert.AreEqual("выпить раф", point.Prompt);
        }
    }
}
