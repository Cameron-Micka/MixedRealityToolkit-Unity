// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#ifndef MRTK_STANDARD_UTILITIES_INCLUDE
#define MRTK_STANDARD_UTILITIES_INCLUDE

/// <summary>
/// Calculates the distance between the camera and a local position.
/// </summary>
inline float DistanceToCameraLocal(float4 localPosition)
{
    return -UnityObjectToViewPos(localPosition).z;
}

/// <summary>
/// Calculates the distance between the camera and a world position.
/// </summary>
inline float DistanceToCameraWorld(float3 worldPosition)
{
    return distance(worldPosition, _WorldSpaceCameraPos);
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

/// <summary>
/// Extracts the world scale from the unity_ObjectToWorld matrix.
/// </summary>
inline float3 ExtractScale(VertexInput input)
{
    float3 output;

    output.x = length(mul(unity_ObjectToWorld, float4(1.0, 0.0, 0.0, 0.0)));
    output.y = length(mul(unity_ObjectToWorld, float4(0.0, 1.0, 0.0, 0.0)));

#if defined(_IGNORE_Z_SCALE)
    output.z = output.x;
#else
    output.z = length(mul(unity_ObjectToWorld, float4(0.0, 0.0, 1.0, 0.0)));
#endif

#if !defined(_VERTEX_EXTRUSION_SMOOTH_NORMALS)
    // uv3.y will contain a negative value when rendered by a UGUI and ScaleMeshEffect.
    if (input.uv3.y < 0.0)
    {
        output.x *= input.uv2.x;
        output.y *= input.uv2.y;
        output.z *= input.uv3.x;
    }
#endif

    return output;
}

/// <summary>
/// Extrudes a vertex along a normal by a distance.
/// </summary>
inline float3 ExtrudeVertex(float3 vertexPosition, float3 normal, float distance)
{
    return vertexPosition + (normal * distance);
}

#endif // MRTK_STANDARD_UTILITIES_INCLUDE
