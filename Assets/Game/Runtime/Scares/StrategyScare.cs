using System;
using System.Collections;
using TMPro;
using UnityEngine;

namespace Game.Scares
{
    /// <summary>
    /// Скример «Стратегия».
    ///
    /// На стене проступает указание. Через несколько секунд оно меняется
    /// на противоположное. Потом ещё раз. Пугает здесь не надпись, а то,
    /// что решение всё время другое, — и любой болельщик Ferrari узнает
    /// это чувство мгновенно.
    ///
    /// Разрядка встроена в саму последовательность: к четвёртой реплике
    /// становится ясно, что это не угроза, а знакомая беспомощность.
    /// Поэтому она показана в мире, а не субтитром.
    /// </summary>
    public sealed class StrategyScare : Scare
    {
        /// <summary>За сколько надпись проступает.</summary>
        private const float AppearSeconds = 0.9f;

        /// <summary>За сколько уходит.</summary>
        private const float FadeSeconds = 0.7f;

        [Serializable]
        public struct WallLine
        {
            public string Text;

            [Tooltip("Сколько держится на стене.")]
            public float HoldSeconds;
        }

        [SerializeField] private TextMeshPro _label;

        /// <summary>
        /// Паузы разной длины намеренно: ровный ритм читался бы как таймер,
        /// а тут важна нервозность.
        /// </summary>
        [SerializeField]
        private WallLine[] _strikeLines =
        {
            new() { Text = "PIT STOP NOW", HoldSeconds = 4f },
            new() { Text = "NO — STAY OUT", HoldSeconds = 3.2f },
            new() { Text = "BOX BOX BOX", HoldSeconds = 2.6f },
        };

        [SerializeField]
        private WallLine _releaseLine = new() { Text = "SORRY. YOUR CALL.", HoldSeconds = 3.4f };

        [SerializeField] private Color _urgentColor = new(0.72f, 0.06f, 0.05f);

        /// <summary>Последняя реплика — уже не крик, а вздох.</summary>
        [SerializeField] private Color _resignedColor = new(0.55f, 0.55f, 0.58f);

        protected override void Awake()
        {
            base.Awake();

            if (_label == null)
            {
                Debug.LogError("Стратегия без надписи — показывать нечего", this);
                return;
            }

            _label.gameObject.SetActive(false);
        }

        protected override void Strike()
        {
            if (_label != null)
            {
                StartCoroutine(ShowSequence());
            }
        }

        private IEnumerator ShowSequence()
        {
            _label.gameObject.SetActive(true);

            foreach (var line in _strikeLines)
            {
                yield return ShowLine(line, _urgentColor);
            }
        }

        protected override IEnumerator Resolve()
        {
            if (_label == null)
            {
                yield break;
            }

            _label.gameObject.SetActive(true);
            yield return ShowLine(_releaseLine, _resignedColor);
            _label.gameObject.SetActive(false);
        }

        /// <summary>
        /// Надпись проступает и гаснет. Мгновенная смена читалась бы как
        /// переключение слайдов, а она должна именно проступать сквозь
        /// штукатурку.
        /// </summary>
        private IEnumerator ShowLine(WallLine line, Color color)
        {
            _label.text = line.Text;

            for (var elapsed = 0f; elapsed < line.HoldSeconds; elapsed += Time.deltaTime)
            {
                var remaining = line.HoldSeconds - elapsed;
                var appearing = Mathf.Clamp01(elapsed / AppearSeconds);
                var leaving = Mathf.Clamp01(remaining / FadeSeconds);

                _label.color = new Color(color.r, color.g, color.b,
                    Mathf.Min(appearing, leaving));
                yield return null;
            }

            _label.color = new Color(color.r, color.g, color.b, 0f);
        }

        /// <summary>Сколько длится удар. Помогает выставить поле в инспекторе.</summary>
        public float StrikeDuration
        {
            get
            {
                var total = 0f;
                foreach (var line in _strikeLines)
                {
                    total += line.HoldSeconds;
                }

                return total;
            }
        }
    }
}
