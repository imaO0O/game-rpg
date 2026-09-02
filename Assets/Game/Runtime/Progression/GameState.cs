using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace Game.Progression
{
    /// <summary>
    /// Состояние прохождения: всё, что переживает перезапуск.
    ///
    /// Обычный класс без Unity-жизненного цикла. Правила прогресса — самая
    /// проверяемая часть игры, и тянуть ради них сцену незачем; со сценой
    /// его связывает единственный компонент <see cref="GameSession"/>.
    /// </summary>
    public sealed class GameState
    {
        private readonly HashSet<string> _shards = new();
        private readonly HashSet<string> _flags = new();

        /// <summary>Осколок подобран. Второй аргумент — сколько их всего стало.</summary>
        public event Action<string, int> ShardCollected;

        public event Action<string> CheckpointReached;

        public int ShardCount => _shards.Count;

        public string CheckpointId { get; private set; } = "";

        public string CheckpointScene { get; private set; } = "";

        public Vector3 CheckpointPosition { get; private set; }

        public float Playtime { get; private set; }

        public bool HasCheckpoint => !string.IsNullOrEmpty(CheckpointId);

        public bool HasShard(string id) => _shards.Contains(id);

        /// <summary>
        /// Подобрать осколок. Возвращает false, если он уже был собран —
        /// так подбор не засчитывается дважды при перезаходе в комнату.
        /// </summary>
        public bool TryCollectShard(string id)
        {
            if (string.IsNullOrEmpty(id) || !_shards.Add(id))
            {
                return false;
            }

            ShardCollected?.Invoke(id, _shards.Count);
            return true;
        }

        public bool HasFlag(string flag) => _flags.Contains(flag);

        /// <summary>
        /// Поднять разовый флаг мира: сыгранный скример, открытая дверь.
        /// Возвращает false, если флаг уже стоял.
        /// </summary>
        public bool TrySetFlag(string flag)
        {
            return !string.IsNullOrEmpty(flag) && _flags.Add(flag);
        }

        public void SetCheckpoint(string id, string scene, Vector3 position)
        {
            CheckpointId = id ?? "";
            CheckpointScene = scene ?? "";
            CheckpointPosition = position;
            CheckpointReached?.Invoke(CheckpointId);
        }

        public void AdvancePlaytime(float deltaTime)
        {
            Playtime += deltaTime;
        }

        /// <summary>Начать заново. Файл сохранения при этом не трогается.</summary>
        public void Reset()
        {
            _shards.Clear();
            _flags.Clear();
            CheckpointId = "";
            CheckpointScene = "";
            CheckpointPosition = Vector3.zero;
            Playtime = 0f;
        }

        public SaveData ToData()
        {
            return new SaveData
            {
                version = SaveData.CurrentVersion,
                shards = _shards.ToArray(),
                flags = _flags.ToArray(),
                checkpoint = new CheckpointData
                {
                    id = CheckpointId,
                    scene = CheckpointScene,
                    x = CheckpointPosition.x,
                    y = CheckpointPosition.y,
                    z = CheckpointPosition.z,
                },
                playtime = Playtime,
            };
        }

        /// <summary>
        /// Восстановить состояние из снимка. Загрузка молча заменяет всё:
        /// подмешивать сохранение к текущему прогрессу — верный способ
        /// получить осколок, собранный дважды.
        /// </summary>
        public void LoadFrom(SaveData data)
        {
            Reset();

            if (data == null)
            {
                return;
            }

            foreach (var id in data.shards)
            {
                if (!string.IsNullOrEmpty(id))
                {
                    _shards.Add(id);
                }
            }

            foreach (var flag in data.flags)
            {
                if (!string.IsNullOrEmpty(flag))
                {
                    _flags.Add(flag);
                }
            }

            var checkpoint = data.checkpoint;
            CheckpointId = checkpoint.id;
            CheckpointScene = checkpoint.scene;
            CheckpointPosition = new Vector3(checkpoint.x, checkpoint.y, checkpoint.z);
            Playtime = data.playtime;
        }
    }
}
