using System.Reflection;
using NUnit.Framework;

namespace Game.Tests
{
    /// <summary>
    /// Поля с [SerializeField] назначаются в префабе, а не кодом. В тестах
    /// префаба нет, поэтому ссылки подставляются рефлексией — расширять ради
    /// этого открытый интерфейс компонентов не стоит.
    ///
    /// Компонент почти всегда читает такие поля в Awake, а тот срабатывает
    /// на AddComponent. Поэтому объект создаётся выключенным, поля ставятся,
    /// и только потом он включается.
    /// </summary>
    internal static class PrivateField
    {
        public static void Set(object target, string name, object value)
        {
            var field = target.GetType().GetField(name,
                BindingFlags.NonPublic | BindingFlags.Instance);
            Assert.IsNotNull(field, $"Нет поля {name} у {target.GetType().Name}");
            field.SetValue(target, value);
        }
    }
}
