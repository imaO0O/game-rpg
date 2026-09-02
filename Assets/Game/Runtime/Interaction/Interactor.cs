using System;
using UnityEngine;

namespace Game.Interaction
{
    /// <summary>
    /// Взаимодействие взглядом: луч из камеры ищет, на что игрок смотрит.
    ///
    /// Отдельным компонентом, а не в контроллере игрока: контроллер отвечает
    /// за движение, а что происходит от нажатия — совсем другая забота,
    /// и она будет расти (осколки, двери, кофемашина, записки).
    ///
    /// Ввод сюда не приходит: нажатие приносит контроллер, вызывая
    /// <see cref="TryInteract"/>. Так весь ввод игрока остаётся в одном месте.
    /// </summary>
    public sealed class Interactor : MonoBehaviour
    {
        [SerializeField] private Camera _camera;

        [Tooltip("На какой дистанции предмет ещё можно взять.")]
        [SerializeField] private float _reach = 2.4f;

        private Interactable _current;

        /// <summary>Игрок перевёл взгляд. Аргумент null — цели нет.</summary>
        public event Action<Interactable> TargetChanged;

        /// <summary>Взаимодействие удалось.</summary>
        public event Action<Interactable> Used;

        /// <summary>На что игрок смотрит сейчас, или null.</summary>
        public Interactable Current => _current;

        private void Awake()
        {
            if (_camera == null)
            {
                Debug.LogError("Interactor без камеры — взаимодействие работать не будет", this);
            }
        }

        private void Update()
        {
            if (_camera == null)
            {
                return;
            }

            SetCurrent(Cast());
        }

        /// <summary>
        /// Нажатие. Возвращает false, если смотреть не на что или цель
        /// отказалась сработать.
        /// </summary>
        public bool TryInteract()
        {
            if (_current == null)
            {
                return false;
            }

            var target = _current;
            if (!target.TryInteract())
            {
                return false;
            }

            Used?.Invoke(target);

            // Осколок исчезает после подбора, кофемашина остаётся на месте.
            // Вместо того чтобы разбирать эти случаи, просто перепроверяем
            // взгляд: Destroy откладывается до конца кадра, и любая проверка
            // на «уничтожен» здесь соврала бы.
            SetCurrent(Cast());

            return true;
        }

        /// <summary>
        /// Луч по маске взаимодействия. Обычная геометрия его не перехватывает —
        /// иначе предмет на столе было бы не взять из-за самого стола.
        /// </summary>
        private Interactable Cast()
        {
            var ray = new Ray(_camera.transform.position, _camera.transform.forward);

            // Мишени — триггеры, поэтому обычного Raycast мало.
            if (!Physics.Raycast(ray, out var hit, _reach,
                    GameLayers.InteractableMask, QueryTriggerInteraction.Collide))
            {
                return null;
            }

            // Мишень может висеть дочерним узлом внутри объекта.
            return hit.collider.GetComponentInParent<Interactable>();
        }

        private void SetCurrent(Interactable found)
        {
            if (found == _current)
            {
                return;
            }

            if (_current != null)
            {
                _current.SetLookedAt(false);
            }

            _current = found;

            if (_current != null)
            {
                _current.SetLookedAt(true);
            }

            TargetChanged?.Invoke(_current);
        }
    }
}
