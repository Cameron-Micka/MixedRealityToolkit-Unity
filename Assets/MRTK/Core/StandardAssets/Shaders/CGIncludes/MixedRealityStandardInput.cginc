// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#ifndef MRTK_STANDARD_INPUT_INCLUDE
#define MRTK_STANDARD_INPUT_INCLUDE

struct VertexInput
{
    float4 vertex : POSITION;
// The default UV channel used for texturing.
float2 uv : TEXCOORD0;
#if defined(LIGHTMAP_ON)
// Reserved for Unity's light map UVs.
float2 uv1 : TEXCOORD1;
#endif
// Used for smooth normal data (or UGUI scaling data).
float4 uv2 : TEXCOORD2;
// Used for UGUI scaling data.
float2 uv3 : TEXCOORD3;
#if defined(_VERTEX_COLORS)
    fixed4 color : COLOR0;
#endif
    fixed3 normal : NORMAL;
#if defined(_NORMAL_MAP)
    fixed4 tangent : TANGENT;
#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct FragmentInput
{
    float4 position : SV_POSITION;
#if defined(_BORDER_LIGHT)
    float4 uv : TEXCOORD0;
#elif defined(_UV)
    float2 uv : TEXCOORD0;
#endif
#if defined(LIGHTMAP_ON)
    float2 lightMapUV : TEXCOORD1;
#endif
#if defined(_VERTEX_COLORS)
    fixed4 color : COLOR0;
#endif
#if defined(_SPHERICAL_HARMONICS)
    fixed3 ambient : COLOR1;
#endif
#if defined(_IRIDESCENCE)
    fixed3 iridescentColor : COLOR2;
#endif
#if defined(_WORLD_POSITION)
#if defined(_NEAR_PLANE_FADE)
    float4 worldPosition : TEXCOORD2;
#else
    float3 worldPosition : TEXCOORD2;
#endif
#endif
#if defined(_SCALE)
    float3 scale : TEXCOORD3;
#endif
#if defined(_NORMAL)
#if defined(_TRIPLANAR_MAPPING)
    fixed3 worldNormal : COLOR3;
    fixed3 triplanarNormal : COLOR4;
    float3 triplanarPosition : TEXCOORD6;
#elif defined(_NORMAL_MAP)
    fixed3 tangentX : COLOR3;
    fixed3 tangentY : COLOR4;
    fixed3 tangentZ : COLOR5;
#else
    fixed3 worldNormal : COLOR3;
#endif
#endif
    UNITY_VERTEX_OUTPUT_STEREO
#if defined(_INSTANCED_COLOR)
        UNITY_VERTEX_INPUT_INSTANCE_ID
#endif
};

#if defined(_INSTANCED_COLOR)
UNITY_INSTANCING_BUFFER_START(Props)
UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
UNITY_INSTANCING_BUFFER_END(Props)
#else
fixed4 _Color;
#endif
sampler2D _MainTex;
fixed4 _MainTex_ST;

#if defined(_ALPHA_CLIP)
fixed _Cutoff;
#endif

fixed _Metallic;
fixed _Smoothness;

#if defined(_CHANNEL_MAP)
sampler2D _ChannelMap;
#endif

#if defined(_NORMAL_MAP)
sampler2D _NormalMap;
float _NormalMapScale;
#endif

#if defined(_EMISSION)
fixed3 _EmissiveColor;
#endif

#if defined(_TRIPLANAR_MAPPING)
float _TriplanarMappingBlendSharpness;
#endif

#if defined(_DIRECTIONAL_LIGHT)
#if defined(_LIGHTWEIGHT_RENDER_PIPELINE)
CBUFFER_START(_LightBuffer)
float4 _MainLightPosition;
half4 _MainLightColor;
CBUFFER_END
#else
fixed4 _LightColor0;
#endif
#endif

#if defined(_REFRACTION)
fixed _RefractiveIndex;
#endif

#if defined(_RIM_LIGHT)
fixed3 _RimColor;
fixed _RimPower;
#endif

#if defined(_VERTEX_EXTRUSION)
float _VertexExtrusionValue;
#endif

#if defined(_NEAR_PLANE_FADE)
float _FadeBeginDistance;
float _FadeCompleteDistance;
fixed _FadeMinValue;
#endif

#if defined(_ROUND_CORNERS)
#if defined(_INDEPENDENT_CORNERS)
float4 _RoundCornersRadius;
#else
fixed _RoundCornerRadius;
#endif
fixed _RoundCornerMargin;
#endif

#if defined(_BORDER_LIGHT)
fixed _BorderWidth;
fixed _BorderMinValue;
#endif

#if defined(_BORDER_LIGHT_OPAQUE)
fixed _BorderLightOpaqueAlpha;
#endif

#if defined(_ROUND_CORNERS) || defined(_BORDER_LIGHT)
fixed _EdgeSmoothingValue;
#endif

#if defined(_INNER_GLOW)
fixed4 _InnerGlowColor;
fixed _InnerGlowPower;
#endif

#if defined(_IRIDESCENCE)
sampler2D _IridescentSpectrumMap;
fixed _IridescenceIntensity;
fixed _IridescenceThreshold;
fixed _IridescenceAngle;
#endif

#if defined(_ENVIRONMENT_COLORING)
fixed _EnvironmentColorThreshold;
fixed _EnvironmentColorIntensity;
fixed3 _EnvironmentColorX;
fixed3 _EnvironmentColorY;
fixed3 _EnvironmentColorZ;
#endif

#endif // MRTK_STANDARD_INPUT_INCLUDE
