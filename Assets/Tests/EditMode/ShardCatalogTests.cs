using System;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using Game.Progression;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestTools;

namespace Game.Tests
{
    public sealed class ShardCatalogTests
    {
        private string _path;

        [SetUp]
        public void SetUp()
        {
            _path = Path.Combine(Path.GetTempPath(), $"shards-test-{Guid.NewGuid():N}.json");
        }

        [TearDown]
        public void TearDown()
        {
            if (File.Exists(_path))
            {
                File.Delete(_path);
            }
        }

        private void WriteRaw(string json)
        {
            File.WriteAllText(_path, json, Encoding.UTF8);
        }

        [Test]
        public void CreateFallback_HasEntriesAndIsMarked()
        {
            var catalog = ShardCatalog.CreateFallback();

            Assert.IsTrue(catalog.IsFallback);
            Assert.Greater(catalog.Total, 0);
        }

        /// <summary>
        /// Отсутствие контента не должно ронять игру: без осколков её всё
        /// равно можно пройти, а private/ по определению может не приехать.
        /// </summary>
        [Test]
        public void Load_WithoutFile_FallsBackAndWarns()
        {
            LogAssert.Expect(LogType.Warning, new Regex("не найден"));

            var catalog = ShardCatalog.Load(_path);

            Assert.IsTrue(catalog.IsFallback);
        }

        [Test]
        public void Load_WithBrokenJson_FallsBack()
        {
            WriteRaw("{ сломано");
            LogAssert.Expect(LogType.Error, new Regex("повреждён"));

            Assert.IsTrue(ShardCatalog.Load(_path).IsFallback);
        }

        [Test]
        public void Load_WithEmptyList_FallsBack()
        {
            WriteRaw("{\"shards\":[]}");
            LogAssert.Expect(LogType.Warning, new Regex("пуст"));

            Assert.IsTrue(ShardCatalog.Load(_path).IsFallback);
        }

        [Test]
        public void Load_WithContent_ReadsCaptionsAndAreas()
        {
            WriteRaw(@"{""shards"":[
                {""id"":""a"",""caption"":""Двор"",""area"":""Рязань""},
                {""id"":""b"",""caption"":""Чердак"",""area"":""Рязань""},
                {""id"":""c"",""caption"":""Боксы"",""area"":""Сочи""}
            ]}");

            var catalog = ShardCatalog.Load(_path);

            Assert.IsFalse(catalog.IsFallback);
            Assert.AreEqual(3, catalog.Total);
            Assert.AreEqual("Чердак", catalog.Caption("b"));
            Assert.AreEqual("Сочи", catalog.Area("c"));
        }

        /// <summary>
        /// Область засчитывается один раз и в порядке появления: карта ставит
        /// флажок за место, а не за каждый осколок.
        /// </summary>
        [Test]
        public void Load_WithRepeatedAreas_KeepsEachOnceInOrder()
        {
            WriteRaw(@"{""shards"":[
                {""id"":""a"",""caption"":""..."",""area"":""Рязань""},
                {""id"":""b"",""caption"":""..."",""area"":""Сочи""},
                {""id"":""c"",""caption"":""..."",""area"":""Рязань""}
            ]}");

            var areas = ShardCatalog.Load(_path).Areas;

            Assert.AreEqual(2, areas.Count);
            Assert.AreEqual("Рязань", areas[0]);
            Assert.AreEqual("Сочи", areas[1]);
        }

        /// <summary>
        /// Незаполненный осколок возвращает свой идентификатор: в кадре это
        /// сразу видно и читается как недоделанный контент, а не как пустое
        /// место, которое легко пропустить.
        /// </summary>
        [Test]
        public void Caption_ForUnknownId_ReturnsIdItself()
        {
            var catalog = ShardCatalog.CreateFallback();

            Assert.AreEqual("нет_такого", catalog.Caption("нет_такого"));
            Assert.AreEqual("", catalog.Area("нет_такого"));
            Assert.IsFalse(catalog.Contains("нет_такого"));
        }

        [Test]
        public void Load_SkipsEntriesWithoutId()
        {
            WriteRaw(@"{""shards"":[
                {""id"":"""",""caption"":""без имени"",""area"":""Дом""},
                {""id"":""a"",""caption"":""Двор"",""area"":""Дом""}
            ]}");

            var catalog = ShardCatalog.Load(_path);

            Assert.AreEqual(1, catalog.Total);
            Assert.IsTrue(catalog.Contains("a"));
        }
    }
}
