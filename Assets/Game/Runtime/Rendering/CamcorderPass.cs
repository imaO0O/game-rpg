using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;

namespace Game.Rendering
{
    /// <summary>
    /// Плёночный вид: кадр пересобирается в низком разрешении и получает
    /// строчную развёртку.
    ///
    /// Референс — Fears to Fathom и подобные: там вид держится не на
    /// качестве моделей, а на слоях обработки поверх простой геометрии.
    /// Поэтому здесь только то, чего у HDRP нет; зерно, хроматическая
    /// аберрация, виньетка, блум и цветокоррекция берутся его штатными
    /// Volume-компонентами.
    ///
    /// Проход идёт после остальной обработки: пикселизовать нужно готовый
    /// кадр, иначе блум и зерно размажут сетку обратно.
    /// </summary>
    [Serializable]
    [VolumeComponentMenu("Post-processing/Game/Плёнка")]
    [SupportedOnRenderPipeline(typeof(HDRenderPipelineAsset))]
    public sealed class CamcorderPass : CustomPostProcessVolumeComponent, IPostProcessComponent
    {
        private const string ShaderName = "Hidden/Game/Camcorder";

        [Tooltip("Высота сетки в строках. Ниже — крупнее пиксель.")]
        public ClampedIntParameter verticalLines = new(288, 90, 1080);

        [Tooltip("Глубина строчной развёртки.")]
        public ClampedFloatParameter scanlineStrength = new(0.18f, 0f, 1f);

        private Material _material;

        private static readonly int VerticalLinesId = Shader.PropertyToID("_VerticalLines");
        private static readonly int ScanlineStrengthId = Shader.PropertyToID("_ScanlineStrength");
        private static readonly int ScanlineScrollId = Shader.PropertyToID("_ScanlineScroll");
        private static readonly int MainTexId = Shader.PropertyToID("_MainTex");

        /// <summary>
        /// Пикселизация обязана быть последней: блум и зерно, наложенные
        /// после неё, размывают сетку и весь смысл теряется.
        /// </summary>
        public override CustomPostProcessInjectionPoint injectionPoint =>
            CustomPostProcessInjectionPoint.AfterPostProcess;

        public bool IsActive() => _material != null && verticalLines.value < 1080;

        public override void Setup()
        {
            var shader = Shader.Find(ShaderName);
            if (shader == null)
            {
                Debug.LogError($"Не найден шейдер {ShaderName} — плёночный вид не включится");
                return;
            }

            _material = new Material(shader) { hideFlags = HideFlags.HideAndDontSave };
        }

        public override void Render(CommandBuffer cmd, HDCamera camera,
            RTHandle source, RTHandle destination)
        {
            if (_material == null)
            {
                HDUtils.BlitCameraTexture(cmd, source, destination);
                return;
            }

            _material.SetFloat(VerticalLinesId, verticalLines.value);
            _material.SetFloat(ScanlineStrengthId, scanlineStrength.value);

            // Развёртка ползёт: неподвижная читается как узор на стекле,
            // а не как запись.
            _material.SetFloat(ScanlineScrollId, Time.time * 2.4f);

            _material.SetTexture(MainTexId, source);
            HDUtils.DrawFullScreen(cmd, _material, destination, shaderPassId: 0);
        }

        public override void Cleanup()
        {
            CoreUtils.Destroy(_material);
            _material = null;
        }
    }
}
