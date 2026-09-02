using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using UnityEngine;

namespace Game.Progression
{
    /// <summary>
    /// Каталог осколков памяти.
    ///
    /// Разделение намеренное и обязательное: код знает только
    /// идентификаторы, а что за ними стоит — подпись, место, фотография,
    /// голосовое — живёт в private/ и в репозиторий не попадает.
    ///
    /// Файл <c>StreamingAssets/private/shards.json</c>:
    /// <code>
    /// {
    ///   "shards": [
    ///     { "id": "night_01", "caption": "...", "area": "..." }
    ///   ]
    /// }
    /// </code>
    /// </summary>
    public sealed class ShardCatalog
    {
        public const string ContentPath = "private/shards.json";

        [Serializable]
        private sealed class Entry
        {
            public string id;
            public string caption;
            public string area;
        }

        [Serializable]
        private sealed class Content
        {
            public Entry[] shards;
        }

        /// <summary>
        /// Заглушки, чтобы каркас работал до появления настоящего контента.
        /// Взяты из ночного дома предыдущей версии — это ровно та область,
        /// в которой происходит игра.
        /// </summary>
        private static readonly Entry[] Fallback =
        {
            new() { id = "night_01", caption = "Двор ночью", area = "Рязань ночью" },
            new() { id = "night_02", caption = "Первый этаж", area = "Рязань ночью" },
            new() { id = "night_03", caption = "За стеной в доме", area = "Рязань ночью" },
            new() { id = "night_04", caption = "Чердак", area = "Рязань ночью" },
            new() { id = "zade_last", caption = "То, что он хранил", area = "Дом" },
        };

        private readonly Dictionary<string, Entry> _entries = new();
        private readonly List<string> _areas = new();

        private ShardCatalog(IEnumerable<Entry> entries)
        {
            foreach (var entry in entries)
            {
                if (entry == null || string.IsNullOrEmpty(entry.id))
                {
                    continue;
                }

                _entries[entry.id] = entry;

                // Области по одному разу и в порядке появления: карта ставит
                // флажок за место, а не за каждый осколок.
                var area = entry.area ?? "";
                if (!string.IsNullOrEmpty(area) && !_areas.Contains(area))
                {
                    _areas.Add(area);
                }
            }
        }

        /// <summary>Сколько осколков всего. Нужно счётчику в интерфейсе.</summary>
        public int Total => _entries.Count;

        public IReadOnlyList<string> Areas => _areas;

        public bool IsFallback { get; private set; }

        /// <summary>
        /// Каталог из StreamingAssets. Если контента нет — заглушки, и об этом
        /// сообщается один раз: без осколков игру всё равно можно проходить,
        /// а падать на пустой папке незачем.
        /// </summary>
        public static ShardCatalog LoadDefault()
        {
            return Load(Path.Combine(Application.streamingAssetsPath, ContentPath));
        }

        public static ShardCatalog Load(string path)
        {
            if (!File.Exists(path))
            {
                Debug.LogWarning($"Каталог осколков не найден ({path}) — работают заглушки");
                return CreateFallback();
            }

            Content content;
            try
            {
                content = JsonUtility.FromJson<Content>(File.ReadAllText(path, Encoding.UTF8));
            }
            catch (Exception exception)
            {
                Debug.LogError($"Каталог осколков повреждён: {exception.Message}");
                return CreateFallback();
            }

            if (content?.shards == null || content.shards.Length == 0)
            {
                Debug.LogWarning("Каталог осколков пуст — работают заглушки");
                return CreateFallback();
            }

            return new ShardCatalog(content.shards);
        }

        public static ShardCatalog CreateFallback()
        {
            return new ShardCatalog(Fallback) { IsFallback = true };
        }

        public bool Contains(string id) => _entries.ContainsKey(id);

        /// <summary>
        /// Подпись осколка. Неизвестный идентификатор возвращает сам себя:
        /// в кадре это сразу видно и читается как незаполненный контент,
        /// а не как пустое место.
        /// </summary>
        public string Caption(string id)
        {
            return _entries.TryGetValue(id, out var entry) && !string.IsNullOrEmpty(entry.caption)
                ? entry.caption
                : id;
        }

        public string Area(string id)
        {
            return _entries.TryGetValue(id, out var entry) ? entry.area ?? "" : "";
        }
    }
}
