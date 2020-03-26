// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#ifndef MRTK_STANDARD_FLUENT_INCLUDE
#define MRTK_STANDARD_FLUENT_INCLUDE

#include "MixedRealityStandardUtilities.cginc"

/// <summary>
/// Fluent properties.
/// </summary>
#define HOVER_LIGHT_COUNT 2
#define HOVER_LIGHT_DATA_SIZE 2
float4 _HoverLightData[HOVER_LIGHT_COUNT * HOVER_LIGHT_DATA_SIZE];
#if defined(_HOVER_COLOR_OVERRIDE)
fixed3 _HoverColorOverride;
#endif

#define PROXIMITY_LIGHT_COUNT 2
#define PROXIMITY_LIGHT_DATA_SIZE 6
float4 _ProximityLightData[PROXIMITY_LIGHT_COUNT * PROXIMITY_LIGHT_DATA_SIZE];
#if defined(_PROXIMITY_LIGHT_COLOR_OVERRIDE)
float4 _ProximityLightCenterColorOverride;
float4 _ProximityLightMiddleColorOverride;
float4 _ProximityLightOuterColorOverride;
#endif

#if defined(_FLUENT_LIGHT) || defined(_BORDER_LIGHT)
fixed _FluentLightIntensity;
#endif

inline float HoverLight(float4 hoverLight, float inverseRadius, float3 worldPosition)
{
    return (1.0 - saturate(length(hoverLight.xyz - worldPosition) * inverseRadius)) * hoverLight.w;
}

inline float ProximityLight(float4 proximityLight,
                            float4 proximityLightParams,
                            float4 proximityLightPulseParams,
                            float3 worldPosition,
                            float3 worldNormal,
                            out fixed colorValue)
{
    float proximityLightDistance = dot(proximityLight.xyz - worldPosition, worldNormal);
#if defined(_PROXIMITY_LIGHT_TWO_SIDED)
    worldNormal = IF(proximityLightDistance < 0.0, -worldNormal, worldNormal);
    proximityLightDistance = abs(proximityLightDistance);
#endif
    float normalizedProximityLightDistance = saturate(proximityLightDistance * proximityLightParams.y);
    float3 projectedProximityLight = proximityLight.xyz - (worldNormal * abs(proximityLightDistance));
    float projectedProximityLightDistance = length(projectedProximityLight - worldPosition);
    float attenuation = (1.0 - normalizedProximityLightDistance) * proximityLight.w;
    colorValue = saturate(projectedProximityLightDistance * proximityLightParams.z);
    float pulse = step(proximityLightPulseParams.x, projectedProximityLightDistance) * proximityLightPulseParams.y;

    return smoothstep(1.0, 0.0, projectedProximityLightDistance / (proximityLightParams.x *
        max(pow(normalizedProximityLightDistance, 0.25), proximityLightParams.w))) * pulse * attenuation;
}

inline fixed3 MixProximityLightColor(fixed4 centerColor, fixed4 middleColor, fixed4 outerColor, fixed t)
{
    fixed3 color = lerp(centerColor.rgb, middleColor.rgb, smoothstep(centerColor.a, middleColor.a, t));
    return lerp(color, outerColor, smoothstep(middleColor.a, outerColor.a, t));
}

inline void FluentLight(float3 worldPosition, 
                        fixed3 worldNormal, 
                        out float fluentLightContribution, 
                        out fixed3 fluentLightColor)
{
    fluentLightContribution = 1.0;
    fluentLightColor = fixed3(0.0, 0.0, 0.0);

    // Hover light.
#if defined(_HOVER_LIGHT)
    fluentLightContribution = 0.0;

    [unroll]
    for (int hoverLightIndex = 0; hoverLightIndex < HOVER_LIGHT_COUNT; ++hoverLightIndex)
    {
        int dataIndex = hoverLightIndex * HOVER_LIGHT_DATA_SIZE;
        fixed hoverValue = HoverLight(_HoverLightData[dataIndex], _HoverLightData[dataIndex + 1].w, worldPosition);
        fluentLightContribution += hoverValue;
#if !defined(_HOVER_COLOR_OVERRIDE)
        fluentLightColor += lerp(fixed3(0.0, 0.0, 0.0), _HoverLightData[dataIndex + 1].rgb, hoverValue);
#endif
    }
#if defined(_HOVER_COLOR_OVERRIDE)
    fluentLightColor = _HoverColorOverride.rgb * fluentLightContribution;
#endif
#endif

    // Proximity light.
#if defined(_PROXIMITY_LIGHT)
#if !defined(_HOVER_LIGHT)
    fluentLightContribution = 0.0;
#endif
    [unroll]
    for (int proximityLightIndex = 0; proximityLightIndex < PROXIMITY_LIGHT_COUNT; ++proximityLightIndex)
    {
        int dataIndex = proximityLightIndex * PROXIMITY_LIGHT_DATA_SIZE;
        fixed colorValue;
        fixed proximityValue = ProximityLight(_ProximityLightData[dataIndex], 
                                              _ProximityLightData[dataIndex + 1], 
                                              _ProximityLightData[dataIndex + 2], 
                                              worldPosition, 
                                              worldNormal, 
                                              colorValue);
        fluentLightContribution += proximityValue;
#if defined(_PROXIMITY_LIGHT_COLOR_OVERRIDE)
        fixed3 proximityColor = MixProximityLightColor(_ProximityLightCenterColorOverride, 
                                                       _ProximityLightMiddleColorOverride, 
                                                       _ProximityLightOuterColorOverride, 
                                                       colorValue);
#else
        fixed3 proximityColor = MixProximityLightColor(_ProximityLightData[dataIndex + 3], 
                                                       _ProximityLightData[dataIndex + 4], 
                                                       _ProximityLightData[dataIndex + 5], 
                                                       colorValue);
#endif  
#if defined(_PROXIMITY_LIGHT_SUBTRACTIVE)
        fluentLightColor -= lerp(fixed3(0.0, 0.0, 0.0), proximityColor, proximityValue);
#else
        fluentLightColor += lerp(fixed3(0.0, 0.0, 0.0), proximityColor, proximityValue);
#endif    
    }
#endif    
}

/// <summary>
/// Lights greater than or equal to this distance are not considered in distance calculations.
/// </summary>
static const float _LightCullDistance = 10.0;

/// <summary>
/// Calculates the distance between the specified light and a vertex. If the light is disabled the distance will be
/// greater than or equal to the "_LightCullDistance."
/// </summary>
inline float DistanceToLight(float4 light, float3 worldPosition)
{
    return distance(worldPosition, light.xyz) + ((1.0 - light.w) * _LightCullDistance);
}

/// <summary>
/// Calculates the distance between the nearest light and a vertex.
/// </summary>
inline float DistanceToNearestLight(float3 worldPosition)
{
    float output = _LightCullDistance;

    [unroll]
    for (int hoverLightIndex = 0; hoverLightIndex < HOVER_LIGHT_COUNT; ++hoverLightIndex)
    {
        int dataIndex = hoverLightIndex * HOVER_LIGHT_DATA_SIZE;
        output = min(output, DistanceToLight(_HoverLightData[dataIndex], worldPosition));
    }

    [unroll]
    for (int proximityLightIndex = 0; proximityLightIndex < PROXIMITY_LIGHT_COUNT; ++proximityLightIndex)
    {
        int dataIndex = proximityLightIndex * PROXIMITY_LIGHT_DATA_SIZE;
        output = min(output, DistanceToLight(_ProximityLightData[dataIndex], worldPosition));
    }

    return output;
}

inline float CalculateNearFade(float3 worldPosition, 
                               float fadeBeginDistance, 
                               float fadeCompleteDistance, 
                               float fadeMinValue)
{
#if defined(_NEAR_LIGHT_FADE)
    float fadeDistance = DistanceToNearestLight(worldPosition);
#else
    float fadeDistance = DistanceToCameraWorld(worldPosition);
#endif
    float rangeInverse = 1.0 / (fadeBeginDistance - fadeCompleteDistance);
    return max(saturate(mad(fadeDistance, rangeInverse, -fadeCompleteDistance * rangeInverse)), fadeMinValue);
}

inline float4 CalculateOrthonormalScale(float3 scale, float3 localNormal)
{
    float4 output;

    // Calculate the axes with the smallest scale.
    output.z = min(min(scale.x, scale.y), scale.z);

#if defined(_BORDER_LIGHT)
    // Calculate the axes with the largest scale.
    float maxScale = max(max(scale.x, scale.y), scale.z);

    // Calculate the scale area along three planes.
    float areaYZ = scale.y * scale.z;
    float areaXZ = scale.z * scale.x;
    float areaXY = scale.x * scale.y;

    // Calculate the ratio of the smallest scale over the middle scale (i.e. not the largest or smallest). 
    float minOverMiddleScale = output.z / (scale.x + scale.y + scale.z - output.z - maxScale);

    output.w = _BorderWidth;
#endif

    // Determine which direction this "face" is pointed in and set the orthonormal scales.
    if (abs(localNormal.x) == 1.0) // Y,Z plane.
    {
        output.x = scale.z;
        output.y = scale.y;

#if defined(_BORDER_LIGHT) 
        if (areaYZ > areaXZ && areaYZ > areaXY)
        {
            output.w *= minOverMiddleScale;
        }
#endif
    }
    else if (abs(localNormal.y) == 1.0) // X,Z plane.
    {
        output.x = scale.x;
        output.y = scale.z;

#if defined(_BORDER_LIGHT) 
        if (areaXZ > areaXY && areaXZ > areaYZ)
        {
            output.w *= minOverMiddleScale;
        }
#endif
    }
    else  // X,Y plane.
    {
        output.x = scale.x;
        output.y = scale.y;

#if defined(_BORDER_LIGHT) 
        if (areaXY > areaYZ && areaXY > areaXZ)
        {
            output.w *= minOverMiddleScale;
        }
#endif
    }
    
    return output;
}

inline float2 CalculateBorderLightScale(float2 scale, float borderWidth)
{
    float scaleRatio = min(scale.x, scale.y) / max(scale.x, scale.y);

    if (scale.x > scale.y)
    {
        return float2(1.0 - (borderWidth * scaleRatio), 1.0 - borderWidth);
    }
    else
    {
        return float2(1.0 - borderWidth, 1.0 - (borderWidth * scaleRatio));
    }
}

/// <summary>
/// Returns the distance the current texel is from the center of the UV coordinates. i.e 0.0 at uv(0.5, 0.5) and 1.0 at 
/// uv(0.0, 0.0) or uv(1.0, 1.0).
/// </summary>
inline float2 CalculateDistanceToUVEdge(float2 uv)
{
    return fixed2(abs(uv.x - 0.5) * 2.0, abs(uv.y - 0.5) * 2.0);
}

/// <summary>
/// Returns the round corner radius based on the current corner if independent corners are enabled.
/// </summary>
inline float GetRoundCornerRadius(float2 uv)
{
#if defined(_ROUND_CORNERS)
#if defined(_INDEPENDENT_CORNERS)
    float4 radius = clamp(_RoundCornersRadius, 0, 0.5);

    if (uv.x < 0.5)
    {
        return (uv.y > 0.5) ? radius.x : radius.w;
    }
    else
    {
        return (uv.y > 0.5) ? radius.y : radius.z;
    }
#else 
     return _RoundCornerRadius;
#endif
#endif

     return 0.0;
}

inline float PointVsRoundedBox(float2 position, float2 cornerCircleDistance, float cornerCircleRadius)
{
    return length(max(abs(position) - cornerCircleDistance, 0.0)) - cornerCircleRadius;
}

inline fixed RoundCornersSmooth(float2 position, 
                                float2 cornerCircleDistance, 
                                float cornerCircleRadius, 
                                float edgeSmoothingValue)
{
    return smoothstep(1.0, 
                      0.0, 
                      PointVsRoundedBox(position, cornerCircleDistance, cornerCircleRadius) / edgeSmoothingValue);
}

inline fixed RoundCorners(float2 position, 
                          float2 cornerCircleDistance, 
                          float cornerCircleRadius, 
                          float edgeSmoothingValue)
{
#if defined(_TRANSPARENT)
    return RoundCornersSmooth(position, cornerCircleDistance, cornerCircleRadius, edgeSmoothingValue);
#else
    return (PointVsRoundedBox(position, cornerCircleDistance, cornerCircleRadius) < 0.0);
#endif
}

inline fixed BorderValue(float4 uv, float2 distanceToUVEdge)
{
#if defined(_BORDER_LIGHT)
    return max(smoothstep(uv.z - _EdgeSmoothingValue, uv.z + _EdgeSmoothingValue, distanceToUVEdge.x),
               smoothstep(uv.w - _EdgeSmoothingValue, uv.w + _EdgeSmoothingValue, distanceToUVEdge.y));
#endif

    return 0.0;
}

inline fixed BorderValueRound(float currentCornerRadius,
                              float cornerCircleRadius,
                              float2 cornerCircleDistance, 
                              float2 cornerPosition,
                              float2 halfScale2D, 
                              float minScale)
{
#if defined(_ROUND_CORNERS)
    fixed borderMargin = _RoundCornerMargin + _BorderWidth * 0.5;
    cornerCircleRadius = saturate(max(currentCornerRadius - borderMargin, 0.01)) * minScale;
    cornerCircleDistance = halfScale2D - (borderMargin * minScale) - cornerCircleRadius;
    return 1.0 - RoundCornersSmooth(cornerPosition, cornerCircleDistance, cornerCircleRadius, _EdgeSmoothingValue);
#endif

    return 0.0;
}

inline void BorderLight(fixed borderValue,
                        float fluentLightContribution,
                        fixed3 fluentLightColor, 
                        inout fixed4 albedo)
{
#if defined(_BORDER_LIGHT)
#if defined(_HOVER_LIGHT) && defined(_BORDER_LIGHT_USES_HOVER_COLOR) && defined(_HOVER_COLOR_OVERRIDE)
    fixed3 borderColor = _HoverColorOverride.rgb;
#else
    fixed3 borderColor = fixed3(1.0, 1.0, 1.0);
#endif
    fixed3 borderContribution = borderColor * borderValue * _BorderMinValue * _FluentLightIntensity;
#if defined(_BORDER_LIGHT_REPLACES_ALBEDO)
    albedo.rgb = lerp(albedo.rgb, borderContribution, borderValue);
#else
    albedo.rgb += borderContribution;
#endif
#if defined(_FLUENT_LIGHT)
    albedo.rgb += (fluentLightColor * borderValue * fluentLightContribution * _FluentLightIntensity) * 2.0;
#endif
#if defined(_BORDER_LIGHT_OPAQUE)
    albedo.a = max(albedo.a, borderValue * _BorderLightOpaqueAlpha);
#endif
#endif
}

fixed3 Iridescence(float2 uv,
                   sampler2D spectrumMap,
                   float threshold, 
                   float angle, 
                   float intensity)
{
    float3 rightTangent = normalize(mul((float3x3)unity_ObjectToWorld, float3(1.0, 0.0, 0.0)));
    float3 incidentWithCenter = normalize(mul(unity_ObjectToWorld, float4(0.0, 0.0, 0.0, 1.0)) - _WorldSpaceCameraPos);

    float k = dot(rightTangent, incidentWithCenter) * 0.5 + 0.5;
    float4 left = tex2D(spectrumMap, float2(lerp(0.0, 1.0 - threshold, k), 0.5), float2(0.0, 0.0), float2(0.0, 0.0));
    float4 right = tex2D(spectrumMap, float2(lerp(threshold, 1.0, k), 0.5), float2(0.0, 0.0), float2(0.0, 0.0));

    float2 XY = uv - float2(0.5, 0.5);
    float s = (cos(angle) * XY.x - sin(angle) * XY.y) / cos(angle);
    return (left.rgb + s * (right.rgb - left.rgb)) * intensity;
}

#endif // MRTK_STANDARD_FLUENT_INCLUDE
