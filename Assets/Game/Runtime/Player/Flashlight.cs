using System;
using UnityEngine;

namespace Game.Player
{
    /// <summary>
    /// Фонарь. Заряд тратится только пока свет горит; у последней четверти
    /// свет желтеет и подрагивает — предупреждение, которое нельзя не
    /// заметить, но паниковать ещё рано.
    ///
    /// Батарея не убивает. Она нужна, чтобы возвращение к кофемашине
    /// было желанным, а не обязательным.
    /// </summary>
    [RequireComponent(typeof(Light))]
    public sealed class Flashlight : MonoBehaviour
    {
        /// <summary>Как часто дрожит свет на исходе заряда, радиан в секунду.</summary>
        private const float FlickerSpeed = 11f;

        /// <summary>Глубина дрожания в самом конце.</summary>
        private const float FlickerDepth = 0.35f;

        /// <summary>До какой доли яркости свет проседает на нуле предупреждения.</summary>
        private const float WarningDimFactor = 0.45f;

        [SerializeField] private float _fullChargeSeconds = 240f;

        [Tooltip("Ниже этого остатка свет начинает мигать и желтеть.")]
        [SerializeField] private float _warningThreshold = 0.22f;

        [SerializeField] private Color _normalColor = new(1f, 0.94f, 0.86f);
        [SerializeField] private Color _warningColor = new(1f, 0.72f, 0.42f);

        private Battery _battery;
        private Light _light;
        private float _fullIntensity;

        /// <summary>Батарея села и свет погас сам.</summary>
        public event Action BatteryDied;

        public float Charge => _battery.Charge;

        public bool IsOn => _light.enabled;

        private void Awake()
        {
            _light = GetComponent<Light>();

            // Яркость из префаба — это и есть «полный» свет. Запоминаем до
            // того, как её начнёт трогать разряд. В HDRP это физическая
            // величина в люменах, но формуле разряда единицы безразличны.
            _fullIntensity = _light.intensity;
            _battery = new Battery(_fullChargeSeconds);
        }

        private void Update()
        {
            if (!_light.enabled)
            {
                return;
            }

            _battery.Drain(Time.deltaTime);

            if (_battery.IsEmpty)
            {
                _light.enabled = false;
                BatteryDied?.Invoke();
                return;
            }

            ApplyCharge();
        }

        /// <summary>
        /// Включить или выключить. На пустой батарее не включается —
        /// щёлкать мёртвым фонарём игрок будет и без нашей помощи.
        /// </summary>
        public void Toggle()
        {
            if (_battery.IsEmpty)
            {
                return;
            }

            _light.enabled = !_light.enabled;
        }

        /// <summary>Полностью заряженная батарея. Нужна точкам покоя.</summary>
        public void Recharge()
        {
            _battery.Recharge();
            ApplyCharge();
        }

        private void ApplyCharge()
        {
            if (_battery.Charge >= _warningThreshold)
            {
                _light.intensity = _fullIntensity;
                _light.color = _normalColor;
                return;
            }

            var remaining = _battery.Charge / _warningThreshold;

            // Дрожание тем заметнее, чем меньше осталось.
            var flicker = 1f - (1f - remaining) * FlickerDepth
                * Mathf.Abs(Mathf.Sin(Time.time * FlickerSpeed));

            _light.intensity = _fullIntensity
                * Mathf.Lerp(WarningDimFactor, 1f, remaining) * flicker;
            _light.color = Color.Lerp(_warningColor, _normalColor, remaining);
        }
    }
}
