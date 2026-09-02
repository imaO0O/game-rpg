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
    /// <summary>
    /// Файл сохранения. Путь всегда временный: тест, пишущий поверх
    /// настоящего прохождения, — худший из возможных.
    /// </summary>
    public sealed class SaveFileTests
    {
        private string _path;
        private SaveFile _file;

        [SetUp]
        public void SetUp()
        {
            _path = Path.Combine(Path.GetTempPath(), $"save-test-{Guid.NewGuid():N}.json");
            _file = new SaveFile(_path);
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
        public void Exists_BeforeAnyWrite_IsFalse()
        {
            Assert.IsFalse(_file.Exists);
        }

        [Test]
        public void TryRead_WithoutFile_ReportsFailure()
        {
            Assert.IsFalse(_file.TryRead(out var data));
            Assert.IsNull(data);
        }

        [Test]
        public void TryWrite_ThenTryRead_RoundTrips()
        {
            var state = new GameState();
            state.TryCollectShard("night_01");
            state.TrySetFlag("scare_pinkie");
            state.SetCheckpoint("kitchen", "House", new Vector3(1f, 2f, 3f));
            state.AdvancePlaytime(42f);

            Assert.IsTrue(_file.TryWrite(state.ToData()));
            Assert.IsTrue(_file.TryRead(out var data));

            var restored = new GameState();
            restored.LoadFrom(data);

            Assert.IsTrue(restored.HasShard("night_01"));
            Assert.IsTrue(restored.HasFlag("scare_pinkie"));
            Assert.AreEqual("kitchen", restored.CheckpointId);
            Assert.AreEqual(new Vector3(1f, 2f, 3f), restored.CheckpointPosition);
            Assert.AreEqual(42f, restored.Playtime, 0.01f);
        }

        /// <summary>
        /// Формат должен чиниться руками, поэтому файл обязан быть
        /// читаемым текстом с понятными именами полей.
        /// </summary>
        [Test]
        public void TryWrite_ProducesReadableJson()
        {
            var state = new GameState();
            state.TryCollectShard("night_01");

            _file.TryWrite(state.ToData());
            var text = File.ReadAllText(_path, Encoding.UTF8);

            StringAssert.Contains("\"version\"", text);
            StringAssert.Contains("\"shards\"", text);
            StringAssert.Contains("night_01", text);
            Assert.Greater(text.Split('\n').Length, 3, "Ожидался развёрнутый JSON, а не одна строка");
        }

        [Test]
        public void TryRead_WithBrokenJson_ReportsFailure()
        {
            WriteRaw("{ это не json ");
            LogAssert.Expect(LogType.Error, new Regex("Сохранение повреждено"));

            Assert.IsFalse(_file.TryRead(out _));
        }

        /// <summary>
        /// Файл из более новой сборки читать нельзя: прочитать наполовину
        /// хуже, чем не читать вовсе — игрок потеряет прогресс молча.
        /// </summary>
        [Test]
        public void TryRead_WithFutureVersion_IsRefused()
        {
            WriteRaw($"{{\"version\":{SaveData.CurrentVersion + 1},\"shards\":[\"night_01\"]}}");
            LogAssert.Expect(LogType.Error, new Regex("новее игры"));

            Assert.IsFalse(_file.TryRead(out _));
        }

        [Test]
        public void TryRead_WithoutVersion_IsLiftedToCurrent()
        {
            WriteRaw("{\"shards\":[\"night_01\"]}");

            Assert.IsTrue(_file.TryRead(out var data));
            Assert.AreEqual(SaveData.CurrentVersion, data.version);
            Assert.AreEqual(1, data.shards.Length);
        }

        /// <summary>
        /// Отсутствующие в файле массивы JsonUtility оставляет пустыми
        /// ссылками. Остальной код не должен об этом знать.
        /// </summary>
        [Test]
        public void TryRead_WithMissingFields_FillsDefaults()
        {
            WriteRaw($"{{\"version\":{SaveData.CurrentVersion}}}");

            Assert.IsTrue(_file.TryRead(out var data));
            Assert.IsNotNull(data.shards);
            Assert.IsNotNull(data.flags);
            Assert.IsNotNull(data.checkpoint);
            Assert.AreEqual("", data.checkpoint.id);

            var state = new GameState();
            Assert.DoesNotThrow(() => state.LoadFrom(data));
            Assert.AreEqual(0, state.ShardCount);
        }

        [Test]
        public void Delete_RemovesFile()
        {
            _file.TryWrite(new GameState().ToData());
            Assert.IsTrue(_file.Exists);

            _file.Delete();

            Assert.IsFalse(_file.Exists);
        }
    }
}
