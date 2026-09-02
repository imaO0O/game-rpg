using Game.Interaction;
using Game.Progression;
using UnityEngine;

namespace Game.World
{
    /// <summary>
    /// Осколок памяти — предмет, который можно взять и рассмотреть.
    ///
    /// Сам предмет ничего не знает о своём содержании: подпись и медиа
    /// приходят из каталога, а тот берёт их из private/. Здесь только
    /// идентификатор.
    ///
    /// Внешний вид, огонёк и мишень взгляда лежат в префабе. Кодом
    /// считается только то, что по своей природе меняется во времени:
    /// вращение и разгорание при взгляде.
    /// </summary>
    public sealed class MemoryShard : Interactable
    {
        [Tooltip("Идентификатор в каталоге осколков.")]
        [SerializeField] private string _id;

        [Tooltip("Что вращается. Обычно модель предмета внутри объекта.")]
        [SerializeField] private Transform _visual;

        [Tooltip("Слабый огонёк: в тёмном доме предмет иначе не найти вовсе.")]
        [SerializeField] private Light _highlight;

        [SerializeField] private float _spinDegreesPerSecond = 40f;
        [SerializeField] private float _idleIntensity = 0.6f;
        [SerializeField] private float _lookIntensity = 3f;

        [Tooltip("Скорость разгорания и угасания огонька.")]
        [SerializeField] private float _glowResponse = 8f;

        public string Id => _id;

        private void Awake()
        {
            if (string.IsNullOrEmpty(_id))
            {
                Debug.LogWarning("Осколок без идентификатора — он не сохранится", this);
                return;
            }

            // Уже собранные не появляются заново при перезаходе в комнату.
            var session = GameSession.Current;
            if (session != null && session.State.HasShard(_id))
            {
                Destroy(gameObject);
            }
        }

        private void Update()
        {
            // Медленное вращение отличает то, что можно взять, от обстановки.
            if (_visual != null)
            {
                _visual.Rotate(Vector3.up, _spinDegreesPerSecond * Time.deltaTime, Space.Self);
            }

            if (_highlight == null)
            {
                return;
            }

            var target = IsLookedAt ? _lookIntensity : _idleIntensity;
            _highlight.intensity = Mathf.Lerp(_highlight.intensity, target,
                1f - Mathf.Exp(-_glowResponse * Time.deltaTime));
        }

        /// <summary>
        /// Взять. Возвращает false, если осколок уже был собран или если
        /// сессии нет — вне игры подбирать некуда.
        /// </summary>
        public override bool TryInteract()
        {
            var session = GameSession.Current;
            if (session == null)
            {
                Debug.LogError("Осколок подобран без активной сессии — прогресс потерян", this);
                return false;
            }

            if (!session.State.TryCollectShard(_id))
            {
                return false;
            }

            // Выключаем до уничтожения: Destroy откладывается до конца кадра,
            // и без этого мишень ещё успела бы попасть под луч взгляда.
            gameObject.SetActive(false);
            Destroy(gameObject);
            return true;
        }
    }
}
