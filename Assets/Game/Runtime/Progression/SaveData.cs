using System;

namespace Game.Progression
{
    /// <summary>
    /// Снимок прохождения на диске.
    ///
    /// Поля публичные и в нижнем регистре не по невнимательности: JsonUtility
    /// переносит имена полей в JSON один в один, а файл сохранения должен
    /// читаться и чиниться руками. Это единственное место в проекте, где
    /// имена подчинены формату файла, а не стилю кода.
    /// </summary>
    [Serializable]
    public sealed class SaveData
    {
        /// <summary>
        /// Текущая версия формата. Растёт, когда меняется смысл полей;
        /// добавление нового поля со значением по умолчанию версию не двигает.
        /// </summary>
        public const int CurrentVersion = 1;

        /// <summary>
        /// Ноль означает файл без версии. Своих таких не бывает, но пустой
        /// или обрезанный JSON даст именно ноль, и это надо отличать.
        /// </summary>
        public const int UnversionedFormat = 0;

        public int version = CurrentVersion;

        public string[] shards = Array.Empty<string>();
        public string[] flags = Array.Empty<string>();
        public CheckpointData checkpoint = new();
        public float playtime;
    }

    /// <summary>
    /// Точка возврата. Позиция разложена по трём числам: JsonUtility умеет
    /// Vector3, но пишет его вложенным объектом, а плоские x/y/z проще
    /// править руками.
    /// </summary>
    [Serializable]
    public sealed class CheckpointData
    {
        public string id = "";
        public string scene = "";
        public float x;
        public float y;
        public float z;
    }
}
