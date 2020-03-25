// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#ifndef MRTK_STANDARD_LIGHTING_INCLUDE
#define MRTK_STANDARD_LIGHTING_INCLUDE

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

#endif // MRTK_STANDARD_INPUT_INCLUDE
