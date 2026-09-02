using System.Collections;
using Game.World;
using UnityEngine;

namespace Game.Scares
{
    /// <summary>
    /// Скример «Дементор».
    ///
    /// Из пара кофемашины вырастает силуэт в балахоне. Разрядка: это Пинки
    /// в простыне. «Экспекто патронум, детка.»
    ///
    /// Срабатывает со второго кофе, а не с первого: первый раз игрок только
    /// нашёл точку покоя, и превращать её в аттракцион сразу — значит отнять
    /// у неё смысл.
    /// </summary>
    public sealed class DementorScare : Scare
    {
        [Tooltip("Машина, из пара которой он растёт.")]
        [SerializeField] private CoffeePoint _coffee;

        [SerializeField] private Transform _shroud;

        [Tooltip("С какого по счёту кофе срабатывает.")]
        [SerializeField] private int _usesBeforeFiring = 2;

        [SerializeField] private float _riseSeconds = 1.2f;

        [Tooltip("За сколько спадает простыня.")]
        [SerializeField] private float _fallSeconds = 0.5f;

        [Tooltip("На сколько ниже точки роста начинается подъём.")]
        [SerializeField] private float _riseFrom = -1.1f;

        private int _uses;

        protected override void Awake()
        {
            base.Awake();

            if (_shroud != null)
            {
                _shroud.gameObject.SetActive(false);
            }

            if (_coffee == null)
            {
                Debug.LogError("Дементору не назначена кофемашина — он не сработает", this);
            }
        }

        private void OnEnable()
        {
            if (_coffee != null)
            {
                _coffee.Used += OnCoffeeUsed;
            }
        }

        private void OnDisable()
        {
            if (_coffee != null)
            {
                _coffee.Used -= OnCoffeeUsed;
            }
        }

        private void OnCoffeeUsed(string _)
        {
            _uses++;
            if (_uses >= _usesBeforeFiring)
            {
                Fire();
            }
        }

        protected override void Strike()
        {
            if (_shroud == null || _coffee == null)
            {
                return;
            }

            StartCoroutine(Rise());
        }

        /// <summary>
        /// Растёт из пара, а не появляется: скачком это читалось бы как
        /// подмена модели, а нужно именно «сгущается».
        /// </summary>
        private IEnumerator Rise()
        {
            var top = _coffee.transform.position + Vector3.up * 0.4f;
            _shroud.position = top + Vector3.up * _riseFrom;
            _shroud.localScale = Vector3.one * 0.3f;
            _shroud.gameObject.SetActive(true);

            for (var elapsed = 0f; elapsed < _riseSeconds; elapsed += Time.deltaTime)
            {
                var t = elapsed / _riseSeconds;
                _shroud.position = Vector3.Lerp(top + Vector3.up * _riseFrom, top, t);
                _shroud.localScale = Vector3.one * Mathf.Lerp(0.3f, 1f, t);
                yield return null;
            }

            _shroud.position = top;
            _shroud.localScale = Vector3.one;
        }

        /// <summary>Простыня спадает: балахон съёживается, и под ним ничего страшного.</summary>
        protected override IEnumerator Resolve()
        {
            if (_shroud == null)
            {
                yield break;
            }

            var from = _shroud.localScale;

            for (var elapsed = 0f; elapsed < _fallSeconds; elapsed += Time.deltaTime)
            {
                _shroud.localScale = Vector3.Lerp(from, Vector3.one * 0.05f,
                    elapsed / _fallSeconds);
                yield return null;
            }

            _shroud.gameObject.SetActive(false);
            _shroud.localScale = Vector3.one;
        }
    }
}
