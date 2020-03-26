// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#ifndef MRTK_STANDARD_LIGHTING_INCLUDE
#define MRTK_STANDARD_LIGHTING_INCLUDE

/// <summary>
/// Lighting constants.
/// </summary>
static const fixed _MinMetallicLightContribution = 0.7;
static const fixed _IblContribution = 0.1;
static const float _Shininess = 800.0;
static const float _FresnelPower = 8.0;

/// <summary>
/// TODO
/// </summary>
inline void DecodeChannelMap(fixed4 channelMapColor, 
                             inout fixed3 albedo, 
                             inout fixed3 emissive,
                             out fixed metallic, 
                             out fixed smoothness)
{
    metallic = channelMapColor.r;
    albedo *= channelMapColor.g;
    emissive *= channelMapColor.b;
    smoothness = channelMapColor.a;
}

/// <summary>
/// TODO
/// </summary>
struct FresnelInput
{
    fixed3 worldNormal;
    fixed3 worldViewVector;
#if defined(_RIM_LIGHT)
    fixed3 rimColor;
    fixed rimPower;
#else
    fixed smoothness;
#endif
};

/// <summary>
/// TODO
/// </summary>
inline fixed3 CalculateFresnel(FresnelInput input)
{
    fixed fresnel = 1.0 - saturate(abs(dot(input.worldViewVector, input.worldNormal)));
#if defined(_RIM_LIGHT)
    return input.rimColor * pow(fresnel, input.rimPower);
#else
    return unity_IndirectSpecColor.rgb * (pow(fresnel, _FresnelPower) * max(input.smoothness, 0.5));
#endif
}

/// <summary>
/// TODO
/// </summary>
struct IBLInput
{
#if defined(_REFLECTIONS) || defined(_REFRACTION)
    fixed3 incidentVector;
    fixed3 worldNormal;
    fixed smoothness;
#if defined(_REFRACTION)
    fixed refractiveIndex;
#endif
#endif
};

/// <summary>
/// TODO
/// </summary>
inline fixed3 CalculateIBL(IBLInput input)
{
    // Image based lighting (attempt to mimic the Standard shader).
#if defined(_REFLECTIONS)
    fixed3 worldReflection = reflect(input.incidentVector, input.worldNormal);
    fixed4 iblData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, 
                                              worldReflection, 
                                              (1.0 - input.smoothness) * UNITY_SPECCUBE_LOD_STEPS);
    fixed3 ibl = DecodeHDR(iblData, unity_SpecCube0_HDR);
#if defined(_REFRACTION)
    fixed4 refractColor = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, 
                                               refract(input.incidentVector, input.worldNormal, input.refractiveIndex));
    ibl *= DecodeHDR(refractColor, unity_SpecCube0_HDR);
#endif
    return ibl;
#endif
    return unity_IndirectSpecColor.rgb;
}

/// <summary>
/// TODO
/// </summary>
inline fixed CalculateDiffuse(fixed3 worldNormal, float4 lightDirection)
{
    return max(0.0, dot(worldNormal, lightDirection));
}

/// <summary>
/// TODO
/// </summary>
inline fixed CalculateSpecular(fixed3 worldNormal, 
                               fixed3 worldViewVector, 
                               float4 lightDirection, 
                               fixed metallic,
                               fixed smoothness)
{
    fixed halfVector = max(0.0, dot(worldNormal, normalize(lightDirection + worldViewVector)));
    return saturate(pow(halfVector, _Shininess * pow(smoothness, 4.0)) * (smoothness * 2.0) * metallic);
}

/// <summary>
/// TODO
/// </summary>
struct SurfaceInput
{
    fixed4 albedo;
    fixed3 ambient;
    fixed metallic;
    fixed smoothness;
#if defined(_DIRECTIONAL_LIGHT) || defined(_REFLECTIONS)
    fixed3 ibl;
    fixed diffuse;
    fixed specular;
#endif
#if defined(_FRESNEL) || defined(_RIM_LIGHT)
    fixed3 fresnel;
#endif
#if defined(_EMISSION)
    fixed3 emission;
#endif
};

/// <summary>
/// TODO
/// </summary>
inline fixed4 CalculateLighting(SurfaceInput input)
{
    fixed4 output = input.albedo;
#if defined(_DIRECTIONAL_LIGHT) || defined(_REFLECTIONS) || defined(_FRESNEL)
    fixed minPhysicalProperty = min(input.smoothness, input.metallic);
#endif
#if defined(_DIRECTIONAL_LIGHT)
    fixed oneMinusMetallic = (1.0 - input.metallic);
    output.rgb = lerp(output.rgb, input.ibl, minPhysicalProperty);
#if defined(_LIGHTWEIGHT_RENDER_PIPELINE)
    fixed3 directionalLightColor = _MainLightColor.rgb;
#else
    fixed3 directionalLightColor = _LightColor0.rgb;
#endif
    output.rgb *= lerp((input.ambient + directionalLightColor * input.diffuse + directionalLightColor * input.specular) * max(oneMinusMetallic, _MinMetallicLightContribution), input.albedo.rgb, minPhysicalProperty);
    output.rgb += (directionalLightColor * input.albedo.rgb * input.specular) + (directionalLightColor * input.specular * input.smoothness);
    output.rgb += input.ibl * oneMinusMetallic * _IblContribution;
#elif defined(_REFLECTIONS)
    output.rgb = lerp(output.rgb, input.ibl, minPhysicalProperty);
    output.rgb *= lerp(input.ambient, input.albedo.rgb, minPhysicalProperty);
#elif defined(_SPHERICAL_HARMONICS)
    output.rgb *= input.ambient;
#endif
#if defined(_FRESNEL)
#if defined(_RIM_LIGHT) || !defined(_REFLECTIONS)
    output.rgb += input.fresnel;
#else
    output.rgb += input.fresnel * (1.0 - minPhysicalProperty);
#endif
#endif
#if defined(_EMISSION)
    output.rgb += input.emission;
#endif
    return output;
}

#endif // MRTK_STANDARD_INPUT_INCLUDE
