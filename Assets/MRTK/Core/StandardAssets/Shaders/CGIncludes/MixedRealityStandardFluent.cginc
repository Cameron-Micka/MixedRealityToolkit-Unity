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

inline float4 CalculateScale2D(float3 scale, float3 localNormal)
{
    float4 output;
    output.z = min(min(scale.x, scale.y), scale.z);

#if defined(_BORDER_LIGHT) 
    float maxScale = max(max(scale.x, scale.y), scale.z);
    float minOverMiddleScale = output.z / (scale.x + scale.y + scale.z - output.z - maxScale);

    float areaYZ = scale.y * scale.z;
    float areaXZ = scale.z * scale.x;
    float areaXY = scale.x * scale.y;

    output.w = _BorderWidth;
#endif

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

fixed3 Iridescence(float tangentDotIncident, 
                   sampler2D spectrumMap, 
                   float threshold, 
                   float2 uv,
                   float angle, 
                   float intensity)
{
    float k = tangentDotIncident * 0.5 + 0.5;
    float4 left = tex2D(spectrumMap, float2(lerp(0.0, 1.0 - threshold, k), 0.5), float2(0.0, 0.0), float2(0.0, 0.0));
    float4 right = tex2D(spectrumMap, float2(lerp(threshold, 1.0, k), 0.5), float2(0.0, 0.0), float2(0.0, 0.0));

    float2 XY = uv - float2(0.5, 0.5);
    float s = (cos(angle) * XY.x - sin(angle) * XY.y) / cos(angle);
    return (left.rgb + s * (right.rgb - left.rgb)) * intensity;
}

#endif // MRTK_STANDARD_FLUENT_INCLUDE
