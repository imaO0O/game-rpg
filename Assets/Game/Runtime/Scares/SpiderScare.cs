using System.Collections;
using UnityEngine;

namespace Game.Scares
{
    /// <summary>
    /// Скример «Паучок».
    ///
    /// В темноте сверху перед лицом резко падает тёмный силуэт вниз головой.
    /// Разрядка мгновенная и вещественная: это фигурка Человека-паука
    /// на нитке, она качается и медленно крутится.
    ///
    /// В отличие от Пинки, он никуда не девается. В этом половина шутки:
    /// мимо него потом можно ходить, и каждый раз это будет напоминать,
    /// на что ты купилась.
    /// </summary>
    public sealed class SpiderScare : Scare
    {
        /// <summary>Насколько быстро затухает раскачка.</summary>
        private const float SwingDecay = 1.1f;

        /// <summary>Ниже этого размаха раскачка считается улёгшейся.</summary>
        private const float SettledDegrees = 3f;

        [Tooltip("Подвес. Крутится вокруг своей точки, игрушка висит под ним.")]
        [SerializeField] private Transform _anchor;

        [Tooltip("С какой высоты над местом покоя падает.")]
        [SerializeField] private float _dropFrom = 2.2f;

        [Tooltip("За сколько долетает. Должно быть быстро — в этом весь удар.")]
        [SerializeField] private float _dropSeconds = 0.18f;

        [Tooltip("Насколько сильно качнёт в первый раз, в градусах.")]
        [SerializeField] private float _swingDegrees = 22f;

        [SerializeField] private float _swingSpeed = 4.5f;

        [Tooltip("Медленное вращение вокруг нитки — оно и выдаёт игрушку.")]
        [SerializeField] private float _spinDegreesPerSecond = 26f;

        [SerializeField] private AudioSource _rustle;

        private Vector3 _restPosition;
        private float _swingTime = -1f;
        private float _spin;

        protected override void Awake()
        {
            base.Awake();

            if (_anchor == null)
            {
                Debug.LogError("Паучку не назначен подвес — падать нечему", this);
                return;
            }

            // Место покоя размечено в сцене: где подвес стоит, там игрушка
            // и висит после падения.
            _restPosition = _anchor.localPosition;
            _anchor.gameObject.SetActive(false);
        }

        private void Update()
        {
            if (_swingTime < 0f || _anchor == null)
            {
                return;
            }

            _swingTime += Time.deltaTime;
            _spin += _spinDegreesPerSecond * Time.deltaTime;

            _anchor.localRotation = Quaternion.Euler(0f, _spin, CurrentSwing());
        }

        /// <summary>Текущий угол отклонения.</summary>
        private float CurrentSwing()
        {
            return SwingEnvelope() * Mathf.Sin(_swingTime * _swingSpeed);
        }

        /// <summary>
        /// Размах раскачки без самого колебания. Ждать нужно именно его:
        /// мгновенный угол проходит через ноль каждые полпериода, и по нему
        /// «улеглось» наступало бы сразу после падения.
        /// </summary>
        public float SwingEnvelope()
        {
            return _swingTime < 0f
                ? 0f
                : _swingDegrees * Mathf.Exp(-SwingDecay * _swingTime);
        }

        protected override void Strike()
        {
            if (_anchor == null)
            {
                return;
            }

            StartCoroutine(Drop());
        }

        private IEnumerator Drop()
        {
            var from = _restPosition + Vector3.up * _dropFrom;
            _anchor.localPosition = from;
            _anchor.localRotation = Quaternion.identity;
            _anchor.gameObject.SetActive(true);

            if (_rustle != null)
            {
                _rustle.Play();
            }

            for (var elapsed = 0f; elapsed < _dropSeconds; elapsed += Time.deltaTime)
            {
                // Ускорение к концу: равномерное падение читается как лифт,
                // а нужно, чтобы оборвалось.
                var t = elapsed / _dropSeconds;
                _anchor.localPosition = Vector3.Lerp(from, _restPosition, t * t);
                yield return null;
            }

            _anchor.localPosition = _restPosition;
            _swingTime = 0f;
        }

        /// <summary>
        /// Разрядка ждёт, пока раскачка уляжется: реплика поверх ещё
        /// болтающейся фигурки прозвучала бы в пустоту.
        /// </summary>
        protected override IEnumerator Resolve()
        {
            if (_anchor == null)
            {
                yield break;
            }

            // Падение может ещё идти, если удар настроен короче него.
            while (_swingTime < 0f)
            {
                yield return null;
            }

            while (SwingEnvelope() > SettledDegrees)
            {
                yield return null;
            }
        }
    }
}
