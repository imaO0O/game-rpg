using System;
using System.IO;
using System.Text;
using UnityEngine;

namespace Game.Progression
{
    /// <summary>
    /// Файл сохранения. Путь приходит извне, а не берётся из Application —
    /// иначе тест писал бы поверх настоящего прохождения.
    ///
    /// Ни одна операция не бросает: сломанное сохранение не повод ронять
    /// игру, о нём достаточно сообщить и начать заново.
    /// </summary>
    public sealed class SaveFile
    {
        private readonly string _path;

        public SaveFile(string path)
        {
            _path = path;
        }

        public bool Exists => File.Exists(_path);

        public bool TryWrite(SaveData data)
        {
            try
            {
                var directory = Path.GetDirectoryName(_path);
                if (!string.IsNullOrEmpty(directory))
                {
                    Directory.CreateDirectory(directory);
                }

                // prettyPrint — ради того же: файл должен читаться глазами.
                File.WriteAllText(_path, JsonUtility.ToJson(data, true), Encoding.UTF8);
                return true;
            }
            catch (Exception exception)
            {
                Debug.LogError($"Не удалось записать сохранение: {exception.Message}");
                return false;
            }
        }

        public bool TryRead(out SaveData data)
        {
            data = null;

            if (!Exists)
            {
                return false;
            }

            SaveData parsed;
            try
            {
                parsed = JsonUtility.FromJson<SaveData>(File.ReadAllText(_path, Encoding.UTF8));
            }
            catch (Exception exception)
            {
                Debug.LogError($"Сохранение повреждено: {exception.Message}");
                return false;
            }

            if (parsed == null)
            {
                Debug.LogError("Сохранение пустое");
                return false;
            }

            if (parsed.version > SaveData.CurrentVersion)
            {
                // Файл из более новой сборки. Прочитать его наполовину хуже,
                // чем не читать вовсе: игрок потеряет прогресс молча.
                Debug.LogError($"Сохранение версии {parsed.version} новее игры " +
                               $"(версия {SaveData.CurrentVersion})");
                return false;
            }

            Normalize(parsed);
            Migrate(parsed);
            data = parsed;
            return true;
        }

        public void Delete()
        {
            try
            {
                if (Exists)
                {
                    File.Delete(_path);
                }
            }
            catch (Exception exception)
            {
                Debug.LogError($"Не удалось удалить сохранение: {exception.Message}");
            }
        }

        /// <summary>
        /// JsonUtility оставляет отсутствующие в файле массивы и объекты
        /// пустыми ссылками, а не значениями по умолчанию. Приводим к виду,
        /// в котором остальной код может не проверять на null.
        /// </summary>
        private static void Normalize(SaveData data)
        {
            data.shards ??= Array.Empty<string>();
            data.flags ??= Array.Empty<string>();
            data.checkpoint ??= new CheckpointData();
            data.checkpoint.id ??= "";
            data.checkpoint.scene ??= "";
        }

        /// <summary>
        /// Подъём старых сохранений до текущего формата. Пока поднимать
        /// нечего: версия одна. Место оставлено намеренно — первая же
        /// миграция без него превращается в правку по всему файлу.
        /// </summary>
        private static void Migrate(SaveData data)
        {
            if (data.version == SaveData.UnversionedFormat)
            {
                data.version = SaveData.CurrentVersion;
            }
        }
    }
}
