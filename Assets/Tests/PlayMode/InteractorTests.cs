using System.Collections;
using Game.Interaction;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestTools;

namespace Game.Tests
{
    /// <summary>
    /// Луч взгляда. Проверяется в Play Mode, потому что весь смысл здесь —
    /// в физике и в масках слоёв, а их без запущенной сцены не выяснить.
    /// </summary>
    public sealed class InteractorTests
    {
        private const float Reach = 2.4f;

        private GameObject _cameraObject;
        private GameObject _targetObject;
        private Interactor _interactor;
        private StubInteractable _target;

        /// <summary>Заглушка: считает нажатия и может отказаться сработать.</summary>
        private sealed class StubInteractable : Interactable
        {
            public int InteractionCount { get; private set; }

            public bool WillSucceed { get; set; } = true;

            public override bool TryInteract()
            {
                InteractionCount++;
                return WillSucceed;
            }
        }

        [SetUp]
        public void SetUp()
        {
            // Объект создаётся выключенным: Awake у Interactor ругается на
            // неназначенную камеру, а назначить её можно только после
            // AddComponent.
            _cameraObject = new GameObject("Camera");
            _cameraObject.SetActive(false);
            var camera = _cameraObject.AddComponent<Camera>();

            _interactor = _cameraObject.AddComponent<Interactor>();
            PrivateField.Set(_interactor, "_camera", camera);
            _cameraObject.SetActive(true);
        }

        [TearDown]
        public void TearDown()
        {
            Object.DestroyImmediate(_cameraObject);
            if (_targetObject != null)
            {
                Object.DestroyImmediate(_targetObject);
            }
        }

        [UnityTest]
        public IEnumerator Update_LookingAtInteractable_SetsCurrent()
        {
            PlaceTarget(distance: 1.5f, layer: GameLayers.Interactable);

            yield return null;

            Assert.AreSame(_target, _interactor.Current);
            Assert.IsTrue(_target.IsLookedAt);
        }

        [UnityTest]
        public IEnumerator Update_TargetBeyondReach_LeavesCurrentEmpty()
        {
            PlaceTarget(distance: Reach + 1f, layer: GameLayers.Interactable);

            yield return null;

            Assert.IsNull(_interactor.Current);
        }

        /// <summary>
        /// Обычная геометрия не должна попадать под луч: иначе предмет
        /// на столе было бы не взять из-за самого стола.
        /// </summary>
        [UnityTest]
        public IEnumerator Update_TargetOnDefaultLayer_IsIgnored()
        {
            PlaceTarget(distance: 1.5f, layer: 0);

            yield return null;

            Assert.IsNull(_interactor.Current);
        }

        [UnityTest]
        public IEnumerator Update_LookingAway_ClearsCurrentAndNotifies()
        {
            PlaceTarget(distance: 1.5f, layer: GameLayers.Interactable);
            yield return null;

            Interactable reported = null;
            var wasNotified = false;
            _interactor.TargetChanged += target =>
            {
                reported = target;
                wasNotified = true;
            };

            _cameraObject.transform.Rotate(Vector3.up, 180f);
            yield return null;

            Assert.IsTrue(wasNotified);
            Assert.IsNull(reported);
            Assert.IsNull(_interactor.Current);
            Assert.IsFalse(_target.IsLookedAt);
        }

        [UnityTest]
        public IEnumerator TryInteract_WithTargetInSight_UsesIt()
        {
            PlaceTarget(distance: 1.5f, layer: GameLayers.Interactable);
            yield return null;

            Interactable used = null;
            _interactor.Used += target => used = target;

            var didInteract = _interactor.TryInteract();

            Assert.IsTrue(didInteract);
            Assert.AreEqual(1, _target.InteractionCount);
            Assert.AreSame(_target, used);
        }

        [UnityTest]
        public IEnumerator TryInteract_WithoutTarget_ReportsFailure()
        {
            yield return null;

            Assert.IsFalse(_interactor.TryInteract());
        }

        /// <summary>
        /// Отказ цели не считается использованием: подсказка остаётся,
        /// и игрок может нажать ещё раз. На этом держится убегающий осколок.
        /// </summary>
        [UnityTest]
        public IEnumerator TryInteract_WhenTargetRefuses_ReportsFailure()
        {
            PlaceTarget(distance: 1.5f, layer: GameLayers.Interactable);
            yield return null;

            _target.WillSucceed = false;
            var wasUsed = false;
            _interactor.Used += _ => wasUsed = true;

            var didInteract = _interactor.TryInteract();

            Assert.IsFalse(didInteract);
            Assert.AreEqual(1, _target.InteractionCount);
            Assert.IsFalse(wasUsed);
        }

        private void PlaceTarget(float distance, int layer)
        {
            _targetObject = new GameObject("Target") { layer = layer };
            _targetObject.transform.position = Vector3.forward * distance;

            var collider = _targetObject.AddComponent<SphereCollider>();
            collider.radius = 0.4f;
            collider.isTrigger = true;

            _target = _targetObject.AddComponent<StubInteractable>();
        }
    }
}
