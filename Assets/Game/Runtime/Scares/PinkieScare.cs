using System.Collections;
using UnityEngine;

namespace Game.Scares
{
    /// <summary>
    /// Скример «Пинки».
    ///
    /// Оборачиваешься — она вплотную к лицу, с шариком, орёт. Разрядка
    /// мгновенная: «ой. я думала, ты знала, что я тут.»
    ///
    /// Единственный скример, который встаёт по направлению взгляда, а не
    /// на заранее размеченное место. Поэтому он и работает: игрок сам
    /// подставляется, и винить некого.
    /// </summary>
    public sealed class PinkieScare : Scare
    {
        /// <summary>
        /// Насколько близко к лицу. Ближе — фигура не помещается в кадр
        /// и читается цветным пятном, дальше — перестаёт пугать.
        /// </summary>
        [SerializeField] private float _faceDistance = 0.85f;

        [Tooltip("Сколько висит перед лицом. Дольше — становится смешно раньше времени.")]
        [SerializeField] private float _inFaceSeconds = 0.45f;

        [Tooltip("Насколько ниже глаз игрока стоят её ноги.")]
        [SerializeField] private float _heightOffset = -0.85f;

        [SerializeField] private Transform _figure;
        [SerializeField] private AudioSource _shout;

        [Header("Подпрыгивание на месте")]
        [SerializeField] private float _bounceAmplitude = 0.06f;
        [SerializeField] private float _bounceSpeed = 12f;

        private float _visibleSeconds;
        private float _groundHeight;

        protected override void Awake()
        {
            base.Awake();

            if (_figure == null)
            {
                Debug.LogError("Пинки без фигуры — пугать нечем", this);
                return;
            }

            _figure.gameObject.SetActive(false);
        }

        private void Update()
        {
            if (_visibleSeconds <= 0f)
            {
                return;
            }

            _visibleSeconds = Mathf.Max(0f, _visibleSeconds - Time.deltaTime);

            // Пока висит перед лицом — покачивается, будто прыгает на месте.
            var bounce = Mathf.Abs(Mathf.Sin(Time.time * _bounceSpeed)) * _bounceAmplitude;
            var position = _figure.position;
            _figure.position = new Vector3(position.x, _groundHeight + bounce, position.z);

            if (_visibleSeconds <= 0f)
            {
                _figure.gameObject.SetActive(false);
            }
        }

        protected override void Strike()
        {
            var eye = FindPlayerEye();
            if (eye == null || _figure == null)
            {
                return;
            }

            // По направлению взгляда, но по горизонтали: если игрок смотрит
            // в пол, она не должна оказаться под ним.
            var forward = eye.transform.forward;
            forward.y = 0f;
            forward = forward.sqrMagnitude > 0.001f ? forward.normalized : eye.transform.up;

            _groundHeight = eye.transform.position.y + _heightOffset;
            _figure.position = eye.transform.position + forward * _faceDistance;
            _figure.position = new Vector3(_figure.position.x, _groundHeight, _figure.position.z);
            _figure.rotation = Quaternion.LookRotation(
                new Vector3(-forward.x, 0f, -forward.z), Vector3.up);

            _figure.gameObject.SetActive(true);
            _visibleSeconds = _inFaceSeconds;

            if (_shout != null)
            {
                _shout.Play();
            }
        }

        protected override IEnumerator Resolve()
        {
            if (_figure != null)
            {
                _figure.gameObject.SetActive(false);
            }

            _visibleSeconds = 0f;
            yield break;
        }
    }
}
