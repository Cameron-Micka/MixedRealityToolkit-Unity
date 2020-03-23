// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#ifndef MRTK_STANDARD_LIGHTING_INCLUDE
#define MRTK_STANDARD_LIGHTING_INCLUDE

inline void CalculateTangentMatrix(fixed3 worldNormal, 
                                   fixed4 tangent, 
                                   out fixed3 tangentX, 
                                   out fixed3 tangentY, 
                                   out fixed3 tangentZ)
{
    fixed3 worldTangent = UnityObjectToWorldDir(tangent.xyz);
    fixed tangentSign = tangent.w * unity_WorldTransformParams.w;
    fixed3 worldBitangent = cross(worldNormal, worldTangent) * tangentSign;
    tangentX = fixed3(worldTangent.x, worldBitangent.x, worldNormal.x);
    tangentY = fixed3(worldTangent.y, worldBitangent.y, worldNormal.y);
    tangentZ = fixed3(worldTangent.z, worldBitangent.z, worldNormal.z);
}

#if defined(_HOVER_LIGHT)
inline float HoverLight(float4 hoverLight, float inverseRadius, float3 worldPosition)
{
    return (1.0 - saturate(length(hoverLight.xyz - worldPosition) * inverseRadius)) * hoverLight.w;
}
#endif

#if defined(_PROXIMITY_LIGHT)
inline float ProximityLight(float4 proximityLight, float4 proximityLightParams, float4 proximityLightPulseParams, float3 worldPosition, float3 worldNormal, out fixed colorValue)
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

    return smoothstep(1.0, 0.0, projectedProximityLightDistance / (proximityLightParams.x * max(pow(normalizedProximityLightDistance, 0.25), proximityLightParams.w))) * pulse * attenuation;
}

inline fixed3 MixProximityLightColor(fixed4 centerColor, fixed4 middleColor, fixed4 outerColor, fixed t)
{
    fixed3 color = lerp(centerColor.rgb, middleColor.rgb, smoothstep(centerColor.a, middleColor.a, t));
    return lerp(color, outerColor, smoothstep(middleColor.a, outerColor.a, t));
}
#endif


#endif // MRTK_STANDARD_INPUT_INCLUDE
