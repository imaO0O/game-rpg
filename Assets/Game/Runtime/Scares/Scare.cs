using System;
using System.Collections;
using Game.Narration;
using Game.Progression;
using UnityEngine;

namespace Game.Scares
{
    /// <summary>
    /// Скример: испуг с обязательной разрядкой.
    ///
    /// Правило жанра — пугает резко, разрешается смешно. Поэтому здесь всегда
    /// два такта: <see cref="Strike"/> бьёт по игроку светом и движением,
    /// <see cref="Resolve"/> через секунду с небольшим объясняет, что это было.
    /// Без второго такта получается обычный хоррор.
    ///
    /// Разрядка обязательна структурно, а не по договорённости: её нельзя
    /// пропустить, не переписав этот класс, а пустую реплику видно
    /// предупреждением при старте сцены.
    ///
    /// Каждый скример срабатывает один раз за прохождение: флаг живёт
    /// в общем состоянии игры и потому переживает перезапуск.
    /// </summary>
    public abstract class Scare : MonoBehaviour
    {
        [Tooltip("Идентификатор для флага. Пустой — скример сработает снова после загрузки.")]
        [SerializeField] private string _id;

        [Tooltip("Сколько длится испуг до разрядки.")]
        [SerializeField] private float _strikeSeconds = 1.3f;

        [SerializeField] private Punchline _punchline;

        [Tooltip("Голос разрядки. Не обязателен: субтитр показывается в любом случае.")]
        [SerializeField] private AudioSource _voice;

        [Tooltip("Разрядка показана в самом мире — надписью или предметом. " +
                 "Тогда субтитр только продублировал бы её.")]
        [SerializeField] private bool _isPunchlineInWorld;

        private bool _isArmed = true;
        private bool _isRunning;

        /// <summary>Удар нанесён.</summary>
        public event Action Struck;

        /// <summary>Разрядка прозвучала, скример закончился.</summary>
        public event Action Resolved;

        public string Id => _id;

        /// <summary>Взведён ли скример. Сработавший больше не стреляет.</summary>
        public bool IsArmed => _isArmed;

        public bool IsRunning => _isRunning;

        public Punchline Punchline => _punchline;

        public string Flag => $"scare_{_id}";

        protected virtual void Awake()
        {
            if (_punchline.IsEmpty)
            {
                Debug.LogWarning(
                    $"Скример «{name}» без разрядки. Удар без разрядки — не скример этой игры.",
                    this);
            }

            if (string.IsNullOrEmpty(_id))
            {
                Debug.LogWarning($"Скример «{name}» без идентификатора сработает заново " +
                                 "после загрузки", this);
                return;
            }

            var session = GameSession.Current;
            if (session != null && session.State.HasFlag(Flag))
            {
                _isArmed = false;
            }
        }

        private void OnTriggerEnter(Collider other)
        {
            if (other.CompareTag("Player"))
            {
                Fire();
            }
        }

        /// <summary>
        /// Запуск. Нужен скримерам, которые срабатывают не от входа в зону,
        /// а от действия игрока — например, от кофемашины. Повторные вызовы
        /// игнорируются так же, как повторный вход.
        /// </summary>
        public bool Fire()
        {
            if (!_isArmed || _isRunning)
            {
                return false;
            }

            _isArmed = false;

            if (!string.IsNullOrEmpty(_id))
            {
                GameSession.Current?.State.TrySetFlag(Flag);
            }

            StartCoroutine(Run());
            return true;
        }

        /// <summary>
        /// Взвести обратно. Нужен там, где событие повторяется несколько раз
        /// подряд, — например, убегающий осколок должен убежать трижды.
        /// </summary>
        public void Rearm()
        {
            _isArmed = true;
        }

        private IEnumerator Run()
        {
            _isRunning = true;

            Strike();
            Struck?.Invoke();

            yield return new WaitForSeconds(_strikeSeconds);

            // Разрядка может длиться: отражение догоняет оригинал, балахон
            // оседает. Реплика звучит после того, как всё улеглось.
            yield return Resolve();

            DeliverPunchline();

            _isRunning = false;
            Resolved?.Invoke();
        }

        /// <summary>Собственно испуг. Мгновенный по своей природе.</summary>
        protected abstract void Strike();

        /// <summary>
        /// Разрядка: убрать за собой. Может занимать время — возвращаемая
        /// последовательность дожидается конца прежде, чем прозвучит реплика.
        /// </summary>
        protected abstract IEnumerator Resolve();

        private void DeliverPunchline()
        {
            if (_voice != null)
            {
                _voice.Play();
            }

            if (_isPunchlineInWorld)
            {
                return;
            }

            GameSession.Current?.Punchlines.Deliver(_punchline);
        }

        /// <summary>
        /// Помощник для наследников: найти голову игрока. Скримеры почти все
        /// работают от того, куда игрок смотрит, а не от того, где он стоит.
        /// </summary>
        protected static Camera FindPlayerEye()
        {
            var player = GameObject.FindGameObjectWithTag("Player");
            return player == null ? null : player.GetComponentInChildren<Camera>();
        }
    }
}
