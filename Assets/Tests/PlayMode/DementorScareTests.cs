using System.Collections;
using Game.Narration;
using Game.Progression;
using Game.Scares;
using Game.World;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestTools;

namespace Game.Tests
{
    /// <summary>
    /// Дементор растёт из пара кофемашины. Проверяется главное: он ждёт
    /// второго кофе, а не первого — иначе точка покоя превращается
    /// в аттракцион ровно тогда, когда её только нашли.
    /// </summary>
    public sealed class DementorScareTests
    {
        private readonly SaveFileGuard _saveGuard = new();

        private GameObject _sessionObject;
        private GameObject _coffeeObject;
        private GameObject _scareObject;

        [SetUp]
        public void SetUp()
        {
            _saveGuard.Take();
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

            if (_coffeeObject != null)
            {
                Object.DestroyImmediate(_coffeeObject);
            }

            Object.DestroyImmediate(_sessionObject);
            _saveGuard.Release();
        }

        private CoffeePoint CreateCoffee()
        {
            _coffeeObject = new GameObject("CoffeePoint");
            _coffeeObject.SetActive(false);
            var point = _coffeeObject.AddComponent<CoffeePoint>();
            PrivateField.Set(point, "_id", "kitchen");
            PrivateField.Set(point, "_drink", "раф");
            // Настоящие шесть секунд передышки в тесте не подождать.
            PrivateField.Set(point, "_restSeconds", 0.1f);
            _coffeeObject.SetActive(true);
            return point;
        }

        private DementorScare CreateScare(CoffeePoint coffee)
        {
            _scareObject = new GameObject("Dementor");
            _scareObject.SetActive(false);

            var shroud = new GameObject("Shroud");
            shroud.transform.SetParent(_scareObject.transform, false);

            var scare = _scareObject.AddComponent<DementorScare>();
            PrivateField.Set(scare, "_id", "dementor");
            PrivateField.Set(scare, "_strikeSeconds", 0.05f);
            PrivateField.Set(scare, "_riseSeconds", 0.05f);
            PrivateField.Set(scare, "_fallSeconds", 0.05f);
            PrivateField.Set(scare, "_coffee", coffee);
            PrivateField.Set(scare, "_shroud", shroud.transform);
            PrivateField.Set(scare, "_punchline",
                new Punchline { Speaker = "Пинки", Line = "экспекто патронум, детка." });

            _scareObject.SetActive(true);
            return scare;
        }

        [UnityTest]
        public IEnumerator FirstCoffee_DoesNotFire()
        {
            var coffee = CreateCoffee();
            var scare = CreateScare(coffee);
            yield return null;

            coffee.TryInteract();
            yield return null;

            Assert.IsTrue(scare.IsArmed, "С первого кофе он ещё не должен вырастать");
            Assert.IsFalse(scare.IsRunning);
        }

        [UnityTest]
        public IEnumerator SecondCoffee_Fires()
        {
            var coffee = CreateCoffee();
            var scare = CreateScare(coffee);
            yield return null;

            coffee.TryInteract();
            // Пока идёт передышка, машина не нажимается — ждём её конца.
            yield return new WaitUntil(() => !coffee.IsResting);

            coffee.TryInteract();
            yield return null;

            Assert.IsFalse(scare.IsArmed, "Со второго кофе он обязан сработать");
        }

        [UnityTest]
        public IEnumerator SecondCoffee_DeliversPunchline()
        {
            var coffee = CreateCoffee();
            CreateScare(coffee);
            yield return null;

            coffee.TryInteract();
            yield return new WaitUntil(() => !coffee.IsResting);
            coffee.TryInteract();

            yield return new WaitForSeconds(0.5f);

            Assert.AreEqual(1, GameSession.Current.Punchlines.DeliveredCount);
            StringAssert.Contains("патронум", GameSession.Current.Punchlines.Last.Line);
        }
    }
}
