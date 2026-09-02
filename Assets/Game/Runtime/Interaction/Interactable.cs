using UnityEngine;

namespace Game.Interaction
{
    /// <summary>
    /// Всё, с чем игрок может что-то сделать по нажатию.
    ///
    /// Общий предок для осколков, кофемашины, дверей и записок. Луч взгляда
    /// ищет именно его, поэтому добавить новый вид взаимодействия — значит
    /// написать наследника, а не трогать контроллер игрока.
    ///
    /// Мишень — обычный триггерный коллайдер на слое Interactable, заданный
    /// в префабе. Кодом ничего не строится.
    /// </summary>
    public abstract class Interactable : MonoBehaviour
    {
        [SerializeField] private string _promptText = "взять";

        /// <summary>
        /// Подпись для подсказки. Наследник может менять её по состоянию —
        /// например, кофемашина сначала предлагает сварить, потом отдохнуть.
        /// </summary>
        public virtual string Prompt => _promptText;

        /// <summary>Наведён ли на объект взгляд.</summary>
        public bool IsLookedAt { get; private set; }

        /// <summary>
        /// Взгляд пришёл или ушёл. Наследник переопределяет, если должен
        /// подсвечиваться, — но базовое состояние обязан сохранить.
        /// </summary>
        public virtual void SetLookedAt(bool value)
        {
            IsLookedAt = value;
        }

        /// <summary>
        /// Собственно действие. Возвращает false, если ничего не произошло —
        /// тогда подсказка не сбрасывается и игрок может нажать ещё раз.
        /// </summary>
        public abstract bool TryInteract();
    }
}
