using System;

namespace Game.Narration
{
    /// <summary>
    /// Разрядка — вторая, обязательная половина скримера.
    ///
    /// Правило жанра: пугает резко, разрешается смешно. Удар без разрядки —
    /// обычный хоррор, а не эта игра.
    /// </summary>
    [Serializable]
    public struct Punchline
    {
        public string Speaker;
        public string Line;

        public bool IsEmpty => string.IsNullOrWhiteSpace(Line);

        public override string ToString()
        {
            return string.IsNullOrWhiteSpace(Speaker) ? Line : $"{Speaker}: {Line}";
        }
    }
}
