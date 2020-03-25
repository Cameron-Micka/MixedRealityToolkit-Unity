// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#ifndef MRTK_STANDARD_FLUENT_INCLUDE
#define MRTK_STANDARD_FLUENT_INCLUDE

#include "MixedRealityStandardUtilities.cginc"

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
