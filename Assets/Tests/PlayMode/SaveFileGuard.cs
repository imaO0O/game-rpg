using System.IO;
using Game.Progression;
using UnityEngine;

namespace Game.Tests
{
    /// <summary>
    /// Отодвигает настоящее сохранение игрока на время теста и возвращает
    /// обратно. Путь берётся из Application и подменить его нечем, а тест,
    /// затирающий чужое прохождение, — худший из возможных.
    /// </summary>
    internal sealed class SaveFileGuard
    {
        private readonly string _savePath;
        private readonly string _backupPath;

        public SaveFileGuard()
        {
            _savePath = Path.Combine(Application.persistentDataPath, GameSession.SaveFileName);
            _backupPath = _savePath + ".test-backup";
        }

        public string SavePath => _savePath;

        public bool SaveExists => File.Exists(_savePath);

        public void Take()
        {
            if (File.Exists(_savePath))
            {
                File.Move(_savePath, _backupPath);
            }
        }

        public void Release()
        {
            if (File.Exists(_savePath))
            {
                File.Delete(_savePath);
            }

            if (File.Exists(_backupPath))
            {
                File.Move(_backupPath, _savePath);
            }
        }
    }
}
