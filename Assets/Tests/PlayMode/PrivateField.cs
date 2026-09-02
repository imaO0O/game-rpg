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
            // GetField не находит приватные поля базового класса: для
            // рефлексии они не унаследованные члены. У скримеров почти всё
            // общее лежит именно в базовом Scare, поэтому идём по иерархии.
            for (var type = target.GetType(); type != null; type = type.BaseType)
            {
                var field = type.GetField(name,
                    BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.DeclaredOnly);
                if (field == null)
                {
                    continue;
                }

                field.SetValue(target, value);
                return;
            }

            Assert.Fail($"Нет поля {name} у {target.GetType().Name} и его предков");
        }
    }
}
