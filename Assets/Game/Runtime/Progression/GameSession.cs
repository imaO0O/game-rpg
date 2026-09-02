using System.IO;
using UnityEngine;

namespace Game.Progression
{
    /// <summary>
    /// Единственное, что переживает смену сцен: состояние прохождения,
    /// файл сохранения и каталог осколков.
    ///
    /// Да, это одиночка — и это осознанное исключение из общего запрета.
    /// К одному и тому же прогрессу обращаются осколки, кофемашины и
    /// скримеры, разбросанные по всей сцене и лежащие в префабах, а префаб
    /// не может держать ссылку на объект сцены. Предыдущая версия решала
    /// это ровно так же — автозагрузкой.
    ///
    /// Больше одиночек в проекте быть не должно.
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class GameSession : MonoBehaviour
    {
        public const string SaveFileName = "save.json";

        private static GameSession _current;

        private SaveFile _saveFile;

        /// <summary>Активная сессия или null, если сцена запущена без неё.</summary>
        public static GameSession Current => _current;

        public GameState State { get; private set; }

        public ShardCatalog Shards { get; private set; }

        public bool HasSave => _saveFile.Exists;

        private void Awake()
        {
            // Вторая сессия появляется при возврате в сцену, где она уже
            // лежит. Побеждает первая: она несёт накопленный прогресс.
            if (_current != null && _current != this)
            {
                Destroy(gameObject);
                return;
            }

            _current = this;
            DontDestroyOnLoad(gameObject);

            State = new GameState();
            Shards = ShardCatalog.LoadDefault();
            _saveFile = new SaveFile(
                Path.Combine(Application.persistentDataPath, SaveFileName));
        }

        private void OnDestroy()
        {
            if (_current == this)
            {
                _current = null;
            }
        }

        private void Update()
        {
            State.AdvancePlaytime(Time.deltaTime);
        }

        public bool Save()
        {
            return _saveFile.TryWrite(State.ToData());
        }

        public bool Load()
        {
            if (!_saveFile.TryRead(out var data))
            {
                return false;
            }

            State.LoadFrom(data);
            return true;
        }

        /// <summary>Начать заново. Файл остаётся на месте до первого сохранения.</summary>
        public void StartOver()
        {
            State.Reset();
        }
    }
}
