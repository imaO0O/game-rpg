Shader "Hidden/Game/Camcorder"
{
    // Плёночный вид: кадр пересобирается в низком разрешении и получает
    // строчную развёртку. Всё остальное — зерно, аберрация, виньетка,
    // блум, цветокоррекция — уже есть у HDRP, и дублировать его незачем.
    HLSLINCLUDE

    #pragma target 4.5
    #pragma only_renderers d3d11 playstation xboxone xboxseries vulkan metal switch

    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/PostProcessing/Shaders/FXAA.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/PostProcessing/Shaders/RTUpscale.hlsl"

    struct Attributes
    {
        uint vertexID : SV_VertexID;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct Varyings
    {
        float4 positionCS : SV_POSITION;
        float2 texcoord   : TEXCOORD0;
        UNITY_VERTEX_OUTPUT_STEREO
    };

    Varyings Vert(Attributes input)
    {
        Varyings output;
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
        output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
        output.texcoord = GetFullScreenTriangleTexCoord(input.vertexID);
        return output;
    }

    TEXTURE2D_X(_MainTex);

    float  _VerticalLines;
    float  _ScanlineStrength;
    float  _ScanlineScroll;

    float4 CustomPostProcess(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

        float2 uv = input.texcoord;

        // Пикселизация. Кадр приводится к сетке заданной высоты, ширина
        // считается от неё по соотношению сторон, чтобы пиксель остался
        // квадратным на любом разрешении.
        float2 grid = float2(_VerticalLines * _ScreenSize.x / _ScreenSize.y, _VerticalLines);
        float2 snapped = (floor(uv * grid) + 0.5) / grid;

        // Точечная выборка, а не линейная: с линейной кадр получается
        // размытым, а не пиксельным — это разные эффекты. Пересчёт координат
        // при этом остаётся «билинейный»: имя обманчиво, он про масштаб
        // буфера RTHandle, а не про фильтрацию, и точечный вариант кадр
        // приближает.
        float3 color = SAMPLE_TEXTURE2D_X_LOD(
            _MainTex, s_point_clamp_sampler,
            ClampAndScaleUVForBilinearPostProcessTexture(snapped), 0.0).xyz;

        // Строчная развёртка. Считается по исходной координате, а не по
        // округлённой: у округлённой дробная часть всегда одна и та же,
        // косинус даёт константу, и вместо строк выходит равномерное
        // затемнение всего кадра.
        float row = uv.y * grid.y + _ScanlineScroll;
        float scan = 1.0 - _ScanlineStrength * (0.5 - 0.5 * cos(row * TWO_PI));
        color *= scan;

        return float4(color, 1.0);
    }

    ENDHLSL

    SubShader
    {
        Tags { "RenderPipeline" = "HDRenderPipeline" }

        Pass
        {
            Name "Camcorder"
            ZWrite Off
            ZTest Always
            Blend Off
            Cull Off

            HLSLPROGRAM
            #pragma fragment CustomPostProcess
            #pragma vertex Vert
            ENDHLSL
        }
    }

    Fallback Off
}
