using System.Collections;
using Game.Interaction;
using Game.Player;
using Game.Progression;
using UnityEngine;

namespace Game.World
{
    /// <summary>
    /// Кофемашина — точка покоя.
    ///
    /// Делает три вещи разом: сохраняет игру, заряжает фонарь и на несколько
    /// секунд включает нормальный свет. Последнее важнее первых двух:
    /// в хорроре передышка должна ощущаться телом, а не отмечаться в меню.
    ///
    /// В каждой комнате свой напиток — настоящий, тот, что она там пила.
    /// </summary>
    public sealed class CoffeePoint : Interactable
    {
        [Tooltip("Идентификатор точки возврата.")]
        [SerializeField] private string _id;

        [Tooltip("Напиток именно этой комнаты. Попадает в подсказку.")]
        [SerializeField] private string _drink;

        [Tooltip("Тёплый огонёк над машиной. Его должно быть видно с другого конца комнаты.")]
        [SerializeField] private Light _light;

        [SerializeField] private ParticleSystem _steam;

        [SerializeField] private float _restSeconds = 6f;

        [Tooltip("Во сколько раз ярче огонёк, когда на него смотрят.")]
        [SerializeField] private float _lookMultiplier = 1.7f;

        [Tooltip("Во сколько раз ярче огонёк во время передышки.")]
        [SerializeField] private float _restMultiplier = 7f;

        [SerializeField] private float _lightResponse = 4f;

        private float _baseIntensity;
        private float _baseSteamRate;
        private bool _isResting;

        public string Id => _id;

        public bool IsResting => _isResting;

        /// <summary>
        /// Подсказка называет напиток, а не действие: «выпить раф» говорит
        /// об этой комнате больше, чем «отдохнуть».
        /// </summary>
        public override string Prompt =>
            string.IsNullOrEmpty(_drink) ? base.Prompt : $"выпить {_drink}";

        private void Awake()
        {
            if (string.IsNullOrEmpty(_id))
            {
                Debug.LogWarning("Кофемашина без идентификатора — точка возврата не сохранится", this);
            }

            if (_light != null)
            {
                _baseIntensity = _light.intensity;
            }

            if (_steam != null)
            {
                _baseSteamRate = _steam.emission.rateOverTimeMultiplier;
            }
        }

        private void Update()
        {
            if (_light == null)
            {
                return;
            }

            var multiplier = 1f;
            if (IsLookedAt)
            {
                multiplier = _lookMultiplier;
            }

            // Передышка перебивает взгляд: во время неё свет разгорается
            // независимо от того, куда игрок смотрит.
            if (_isResting)
            {
                multiplier = _restMultiplier;
            }

            _light.intensity = Mathf.Lerp(_light.intensity, _baseIntensity * multiplier,
                1f - Mathf.Exp(-_lightResponse * Time.deltaTime));
        }

        public override bool TryInteract()
        {
            if (_isResting)
            {
                return false;
            }

            var session = GameSession.Current;
            if (session == null)
            {
                Debug.LogError("Кофемашина без активной сессии — сохранять некуда", this);
                return false;
            }

            session.State.SetCheckpoint(_id, gameObject.scene.name, transform.position);
            session.Save();

            RechargePlayer();
            StartCoroutine(Rest());
            return true;
        }

        /// <summary>Передышка: пар идёт гуще, свет разгорается, потом всё возвращается.</summary>
        private IEnumerator Rest()
        {
            _isResting = true;
            SetSteamRate(_baseSteamRate * 3f);

            yield return new WaitForSeconds(_restSeconds);

            _isResting = false;
            SetSteamRate(_baseSteamRate);
        }

        private void SetSteamRate(float rate)
        {
            if (_steam == null)
            {
                return;
            }

            var emission = _steam.emission;
            emission.rateOverTimeMultiplier = rate;
        }

        private void RechargePlayer()
        {
            var player = GameObject.FindGameObjectWithTag("Player");
            if (player == null)
            {
                return;
            }

            var flashlight = player.GetComponentInChildren<Flashlight>();
            if (flashlight != null)
            {
                flashlight.Recharge();
            }
        }
    }
}
